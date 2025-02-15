$instanceName = Read-Host "Por favor, insira o nome da instância (rancher)"

if (-not $instanceName) {
    $instanceName = "rancher"
}

$groupName = (Get-Culture).TextInfo.ToTitleCase($instanceName.ToLower())

$instances = aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*$instanceName*" "Name=instance-state-name,Values=running,stopped" `
    --query "Reservations[*].Instances[*].InstanceId" `
    --output text

if ($instances -and $instances -ne "") {
    $instanceArray = $instances -split "\s+"
    
    Write-Output "ℹ️ Instância(s) encontrada(s): $instances"
    
    $instancesTerminated = aws ec2 terminate-instances `
        --instance-ids $instanceArray `
        --query "TerminatingInstances[*].InstanceId" `
        --output text

    foreach ($instanceId in $instancesTerminated -split "\s+") {
        Write-Output "Instância $instanceId terminada."
    }
    
    Write-Output "⏳ Aguardando a remoção completa das instâncias..."
        
    aws ec2 wait instance-terminated --instance-ids $instanceArray
        
    Write-Output "✅ Instância(s) excluídas: $instances"
}
else {
    Write-Output "ℹ️ Nenhuma instância encontrada para remoção."
}

$securityGroup = aws ec2 describe-security-groups `
    --filters "Name=group-name,Values=$groupName" `
    --query "SecurityGroups[0].GroupId" `
    --output text

if (-not $securityGroup) {
    Write-Output "❌ Nenhum Security Group encontrado com o nome $groupName. Verifique e tente novamente."
    exit 1
}

$subnetId = aws ec2 describe-subnets `
    --filters "Name=tag:Name,Values=*public*1a*" `
    --query "Subnets[0].SubnetId" `
    --output text

if (-not $subnetId) {
    Write-Output "❌ Nenhuma Subnet encontrada para *public*1a*. Verifique se existe e tente novamente."
    exit 1
}

$imageId = "ami-0c6f9998440436fb9"
$instanceType = "t3.medium"
$keyName = "pedro"
$volumeSize = 50
$hostedZoneId = "Z10217832HLWH22EU1VJL"
$recordServer1 = $instanceName.ToLower() + ".itacarambi.tec.br"
$recordClient1 = $instanceName.ToLower() + "-k8s-1.itacarambi.tec.br"
$recordClient2 = $instanceName.ToLower() + "-k8s-2.itacarambi.tec.br"
$recordClient3 = $instanceName.ToLower() + "-k8s-3.itacarambi.tec.br"
$tags = @($recordServer1, $recordClient1, $recordClient2, $recordClient3)

$instanceIds = aws ec2 run-instances `
    --image-id $imageId `
    --instance-type $instanceType `
    --key-name $keyName `
    --security-group-ids $securityGroup `
    --network-interfaces "SubnetId=$subnetId,AssociatePublicIpAddress=true,DeviceIndex=0,Groups=[$securityGroup]" `
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$volumeSize,VolumeType=gp3}" `
    --credit-specification "CpuCredits=unlimited" `
    --metadata-options "HttpEndpoint=enabled,HttpPutResponseHopLimit=2,HttpTokens=required" `
    --private-dns-name-options "HostnameType=ip-name,EnableResourceNameDnsARecord=false,EnableResourceNameDnsAAAARecord=false" `
    --count "4" `
    --query "Instances[*].InstanceId" `
    --output json | ConvertFrom-Json

if (-not $instanceIds -or $instanceIds.Count -eq 0) {
    Write-Output "❌ Falha na criação das instâncias. Verifique os logs do AWS CLI."
    exit 1
}

Write-Output "Criando instâncias..."
Write-Output "⏳ Aguardando todas as instâncias ficarem prontas... Isso pode levar alguns minutos."

$spinner = @("|", "/", "-", "\")  # Animação simples
$counter = 0

while ($true) {
    $status = aws ec2 describe-instance-status `
        --instance-ids $instanceIds `
        --query "InstanceStatuses[*].InstanceState.Name" `
        --output text

    if ($status -match "running") { break }  

    Write-Host "`r$($spinner[$counter % 4]) Esperando..." -NoNewline  
    Start-Sleep -Milliseconds 500  
    $counter++  
}

Write-Output "`r✅ Todas as instâncias estão prontas!"

if ($instanceIds) {
    for ($i = 0; $i -lt $instanceIds.Count; $i++) {
        aws ec2 create-tags `
            --resources $instanceIds[$i] `
            --tags "Key=Name,Value=$($tags[$i])"
        
        Write-Output "Instância $($instanceIds[$i]) criada com o ID $($tags[$i])"

    }

    for ($i = 0; $i -lt $instanceIds.Count; $i++) {
        $publicIp = aws ec2 describe-instances `
            --instance-ids $($instanceIds[$i]) `
            --query "Reservations[0].Instances[0].PublicIpAddress" `
            --output text
    
        if (-not $publicIp -or $publicIp -eq "None") {
            Write-Output "⚠️  Instância $($instanceIds[$i]) ($($tags[$i])) não possui IP público. Pulando atualização DNS..."
            continue
        }
    
        Write-Output "Obtido o IP público da instância $($instanceIds[$i]) ($($tags[$i])): $publicIp"
        Write-Output "Adicionando o IP ao registro DNS da instância..."
    
        $changeBatch = @{
            Comment = "Registro atualizado com o novo IP da instância."
            Changes = @(
                @{
                    Action            = "UPSERT"
                    ResourceRecordSet = @{
                        Name            = $tags[$i]
                        Type            = "A"
                        TTL             = 60
                        ResourceRecords = @(@{ Value = $publicIp })
                    }
                }
            )
        } | ConvertTo-Json -Depth 10 -Compress
    
        # Write-Output "JSON gerado para Route 53:"
        # Write-Output $changeBatch
    
        aws route53 change-resource-record-sets `
            --hosted-zone-id $hostedZoneId `
            --change-batch "$changeBatch"
    
        Write-Output "✅ Registro DNS atualizado na Route 53 com o novo IP: $publicIp"
    }
}
else {
    Write-Output "❌ Falha na criação das instâncias."
}

$instanceStatus = aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=*$instanceName*" `
    --query "Reservations[*].Instances[*].[InstanceId,State.Name]" `
    --output table

Write-Output "ℹ️ Total de instâncias e seus respectivos status:"
Write-Output $instanceStatus
