
# Prerequisitos

- 4 máquinas virtuais com 2/4 processadores e 6/8 gb de memória ram
- 1 domínio
- Sistema operacional Ubuntu
- Domínio usado pelo instrutor do curso é: itacarambi.tec.br

https://github.com/jonathanbaraldi/devops

# Aula 4 - Ambiente

Nesta aula, iremos verificar a instalação do Docker, e também iremos revisar a arquitetura do ambiente.

É preciso entrar em todas as máquinas e instalar o Docker.

```bash
ssh -i pedro.pem ec2-user@rancher.itacarambi.tec.br
ssh -i pedro.pem ec2-user@rancher-k8s-1.itacarambi.tec.br
ssh -i pedro.pem ec2-user@rancher-k8s-2.itacarambi.tec.br
ssh -i pedro.pem ec2-user@rancher-k8s-3.itacarambi.tec.br
```

```powershell
initial_deploy_aws.ps1
```

# Aula 5 - Construindo sua aplicação

### Fazer build das imagens, rodar docker-compose

Nesse exercício iremos construir as imagens dos containers que iremos usar, colocar elas para rodar em conjunto com o docker-compose. 

Sempre que aparecer \<dockerhub-user\>, você precisa substituir pelo seu usuário no DockerHub.

Entrar no host A, e instalar os pacotes abaixo, que incluem Git, Python, Pip e o Docker-compose.

```bash
sudo su -

vi /etc/selinux/config
:%s/enforcing/disabled/g
reboot

sudo su -

yum upgrade -y;systemctl disable nm-cloud-setup.service;systemctl disable nm-cloud-setup.timer;systemctl stop nm-cloud-setup.service;systemctl stop nm-cloud-setup.timer;timedatectl set-timezone America/Sao_Paulo;timedatectl;reboot

sudo su -

yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo;dnf install docker-ce docker-ce-cli git vim net-tools wget zsh telnet -y;usermod -aG docker root;systemctl start docker;docker ps;systemctl enable docker;curl -L "https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose;chmod +x /usr/local/bin/docker-compose;ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose;git clone https://github.com/phximenes/devops /opt/devops;chown -R ec2-user:ec2-user /opt/devops;sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

#### Container=REDIS
Iremos fazer o build da imagem do Redis para a nossa aplicação.
```bash
cd redis

docker build -t phximenes/redis:devops .

docker run -d --name redis -p 6379:6379 phximenes/redis:devops

docker ps

docker logs redis
```
Com isso temos o container do Redis rodando na porta 6379.



#### Container=NODE
Iremos fazer o build do container do NodeJs, que contém a nossa aplicação.
```bash
cd ../node

docker build -t phximenes/node:devops .
```
Agora iremos rodar a imagem do node, fazendo a ligação dela com o container do Redis.
```bash
docker run -d --name node -p 8080:8080 --link redis phximenes/node:devops

docker ps

docker logs node
```
Com isso temos nossa aplicação rodando, e conectada no Redis. A api para verificação pode ser acessada em /redis.



#### Container=NGINX
Iremos fazer o build do container do nginx, que será nosso balanceador de carga.
```bash
cd ../nginx

docker build -t phximenes/nginx:devops .
```
Criando o container do nginx a partir da imagem e fazendo a ligação com o container do Node
```bash
docker run -d --name nginx -p 80:80 --link node phximenes/nginx:devops

docker ps

docker logs nginx
```
Podemos acessar então nossa aplicação nas portas 80 e 8080 no ip da nossa instância.

Iremos acessar a api em /redis para nos certificar que está tudo ok, e depois iremos limpar todos os containers e volumes.
```bash
docker rm -f $(docker ps -a -q)

docker volume rm $(docker volume ls)
```


#### DOCKER-COMPOSE
Nesse exercício que fizemos agora, colocamos os containers para rodar, e interligando eles, foi possível observar como funciona nossa aplicação que tem um contador de acessos.
Para rodar nosso docker-compose, precisamos remover todos os containers que estão rodando e ir na raiz do diretório para rodar.

É preciso editar o arquivo docker-compose.yml, onde estão os nomes das imagens e colocar o seu nome de usuário.

- Linha 8 = phximenes/nginx:devops
- Linha 18 = image: phximenes/redis:devops
- Linha 37 = image: phximenes/node:devops

Após alterar e colocar o nome correto das imagens, rodar o comando de up -d para subir a stack toda.

```bash
cd /opt/devops/exercicios/app

vim docker-compose.yml
```

Dentro do VIM executar:
```vim
:%s/salimfpf/phximenes/g
```

```bash
docker-compose -f docker-compose.yml up -d

docker ps

curl localhost:80
```

Se acessarmos o IP:80, iremos acessar a nossa aplicação. Olhar os logs pelo docker logs, e fazer o carregamento do banco em /load

Para terminar nossa aplicação temos que rodar o comando do docker-compose abaixo:
```bash
docker-compose down
```











# Aula 6 - Rancher - Single Node

### Instalar Rancher - Single Node

Nesse exercício iremos instalar o Rancher 2.2.5 versão single node. Isso significa que o Rancher e todos seus componentes estão em um container. 

Entrar no host A, que será usado para hospedar o Rancher Server. Iremos verficar se não tem nenhum container rodando ou parado, e depois iremos instalar o Rancher.
```bash
cat <<EOF | sudo tee /etc/modules-load.d/iptables.conf
iptable_filter
iptable_nat
iptable_mangle
EOF

modprobe iptable_filter;modprobe iptable_nat;modprobe iptable_mangle;docker ps -a

docker run -d --name rancher --restart=unless-stopped -v /opt/rancher:/var/lib/rancher --privileged -p 80:80 -p 443:443 -p 9345:9345 rancher/rancher

docker logs rancher 2>&1 | grep "Bootstrap Password:"

docker logs -f rancher

docker exec -it rancher bash
```

Com o Rancher já rodando, irei adicionar a entrada de cada DNS para o IP de cada máquina.
https://rancher.itacarambi.tec.br

rancher.itacarambi.tec.br = IP do host A












# Aula 7 - Kubernetes

### Criar cluster Kubernetes

Nesse exercício iremos criar um cluster Kubernetes. Após criar o cluster, iremos instalar o kubectl no host A, e iremos usar para interagir com o cluster.

Seguir as instruções na aula para fazer o deployment do cluster.
Após fazer a configuração, o Rancher irá exibir um comando de docker run, para adicionar os host's.

Adicionar o host B e host C.

Pegar o seu comando no seu rancher.
```bash
curl --insecure -fL https://rancher.itacarambi.tec.br/system-agent-install.sh | sh -s - --server https://rancher.itacarambi.tec.br --label 'cattle.io/os=linux' --token 2vf55xsl99hngzf7dspfbzp88n6cwzrlph9xnbvrm728xlvlmgn99n --ca-checksum 165b9ab782a6161d2f11fb3921f61da4e913bf4752756ed87b122d5ad38ac9e5 --etcd --controlplane --worker;tail -f /var/log/messages
```
Será um cluster com 3 nós.
Navegar pelo Rancher e ver os painéis e funcionalidades.












# Aula 8 - Kubectl

### Instalar kubectl no host A

Agora iremos instalar o kubectl, que é a CLI do kubernetes. Através do kubectl é que iremos interagir com o cluster.
```bash
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF

dnf install -y kubectl

curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash

mv kustomize /usr/bin
```

Com o kubectl instalado, pegar as credenciais de acesso no Rancher e configurar o kubectl.

```bash
mkdir ~/.kube;vim ~/.kube/config

kubectl version

kubectl get nodes

kubectl get pods -n kube-system
```









# Aula 9 - DNS

### Traefik - DNS

*.rancher.itacarambi.tec.br


O Traefik é a aplicação que iremos usar como ingress. Ele irá ficar escutando pelas entradas de DNS que o cluster deve responder. Ele possui um dashboard de monitoramento e com um resumo de todas as entradas que estão no cluster.
```bash
#######$ kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v1.7/examples/k8s/traefik-rbac.yaml
#######$ kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v1.7/examples/k8s/traefik-ds.yaml
#######$ kubectl --namespace=kube-system get pods

# Install Traefik Resource Definitions:
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.3/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml

# Install RBAC for Traefik:
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.3/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml

# Outros examples: https://github.com/traefik/traefik/tree/master/docs/content/reference/dynamic-configuration
```
Agora iremos configurar o DNS pelo qual o Traefik irá responder. No arquivo ui.yml, localizar a url, e fazer a alteração. Após a alteração feita, iremos rodar o comando abaixo para aplicar o deployment no cluster.
```bash
#$ cd treinamento-kubernetes/exercicios/
#$ kubectl apply -f ui.yml
```







# Aula 10 - Volume

### Volumes

Para fazermos os exercícios do volume, iremos fazer o deployment do pod com o volume, que estará apontando para um caminho no host.

Fazer o deployment do Longhorn.


```bash
$ kubectl apply -f mariadb-longhorn-volume.yml
```







# Aula 11 - LOG

### Graylog - LOG

O Graylog é a aplicação que iremos usar como agregador de logs do cluster. Os logs dos containers podem ser vistos pelo Rancher, é um dos níveis de visualização. Pelo Graylog temos outros funcionalidades, e também é possível salvar para posterior pesquisa, e muitas outras funcionalidades.

Para instalar o Graylog, iremos aplicar o template dele, que está em graylog.yml. Para isso, é preciso que sejam editados 2 pontos no arquivo.


- Linha 264 - value: http://graylog.rancher.<dominino>/api
- Linha 340 - host: graylog.rancher.<dominio>

Substituir o {user}, pelo nome do aluno. Após substituir, aplicar e entrar no Graylog para configurar.
```bash
$ kubectl apply -f graylog.yml
```
Seguir os passos do instrutor para configuração do Graylog.











# Aula 12 - Monitoramento

### Grafana - MONITORAMENTO

O Grafana/Prometheus é a stack que iremos usar para monitoramento. O Deployment dela será feito pelo Catálogo de Apps.
Iremos configurar seguindo as informações do instrutor, e fazer o deployment.

Será preciso altear os DNS das aplicações para que elas fiquem acessíveis.

Após o deploymnet, entrar no Grafana e Prometheus e mostrar seu funcionamento.









# Aula 13 - CronJob

### CronJob

O tipo de serviço como CronJob é um serviço igual a uma cron, porém é executado no cluster kubernetes. Você agenda um pod que irá rodar em uma frequência determinada de tempo. Pode ser usado para diversas funções, como executar backup's dos bancos de dados.

Nesse exemplo, iremos executar um pod, com um comando para retornar uma mensagem de tempos em tempos, a mensagem é "Hello from the Kubernetes cluster"

```bash
$ kubectl apply -f cronjob.yml
	cronjob "hello" created
```
Depois de criada a cron, pegamos o estado dela usando:
```bash
$ kubectl get cronjob hello
NAME      SCHEDULE      SUSPEND   ACTIVE    LAST-SCHEDULE
hello     */1 * * * *   False     0         <none>
```
Ainda não existe um job ativo, e nenhum agendado também.
Vamos esperar por 1 minutos ate o job ser criado:
```bash
$ kubectl get jobs --watch
```
Entrar no Rancher para ver os logs e a sequencia de execucao.











# Aula 14 - ConfigMap

### ConfigMap

O ConfigMap é um tipo de componente muito usado, principalmente quando precisamos colocar configurações dos nossos serviços externas aos contâiners que estão rodando a aplicação. 

Nesse exemplo, iremos criar um ConfigMap, e iremos acessar as informações dentro do container que está a aplicação.
```bash
$ kubectl apply -f configmap.yml
```
Agora iremos entrar dentro do container e verificar as configurações definidas no ConfigMap.













# Aula 15 - Secrets

### Secrets

Os secrets são usados para salvar dados sensitivos dentro do cluster, como por exemplo senhas de bancos de dados. Os dados que ficam dentro do secrets não são visíveis a outros usuários, e também podem ser criptografados por padrão no banco.

Iremos criar os segredos.

```bash
$ echo -n "<nome-aluno>" | base64
am9uYXRoYW5iYXJhbGRp
$ echo -n "<senha>" | base64
am9uam9u
```

Agora vamos escrever o secret com esses objetos. Após colocar os valores no arquivo secrets.yml, aplicar ele no cluster.
```bash
$ kubectl apply -f secrets.yml
```
Agora com os secrets aplicados, iremos entrar dentro do container e ver como podemos recuperar seus valores.














# Aula 16 - Liveness

### Liveness

Nesse exercício do liveness, iremos testar como fazer para dizer ao kubernetes, quando recuperar a nossa aplicação, caso alguma coisa aconteça a ela.
```js
http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) { 
	duration := time.Now().Sub(started) 
	if duration.Seconds() > 10 { 
		w.WriteHeader(500) 
		w.Write([]byte(fmt.Sprintf("error: %v", duration.Seconds()))) 
	} else { 
		w.WriteHeader(200) 
		w.Write([]byte("ok")) 
	} 
})
```
O código acima, está dentro do container que iremos rodar. Nesse código, vocês podem perceber que tem um IF, que irá fazer que de vez em quando a aplicação responda dando erro. 

Como a aplicação irá retornar um erro, o serviço de liveness que iremos usar no Kubernetes, ficará verificando se a nossa aplicação está bem, e como ela irá falhar de tempos em tempos, o kubernetes irá reiniciar o nosso serviço.

```bash
$ kubectl apply -f liveness.yml 
	Depois de 10 segundos, verificamos que o container reiniciou. 
$ kubectl describe pod liveness-http 
$ kubectl get pod liveness-http 
```











# Aula 17 - SetImage

### SetImage


Nesse exercício de rolling-update, iremos fazer o deployment do nginx na versão 1.7.9. Sendo 5 pods rodando a aplicação.

Iremos rodar o comando de rolling update, para atualizar para a versão 1.9.1. Dessa forma o Kubernetes irá rodar 1 container com a nova versão, e para um container com a antiga versão. Ele irá fazer isso para cada um dos containers, substituindo todos eles, e não havendo parada de serviço.

```bash
$ kubectl apply -f rolling-update.yml
```
Nesse arquivo o nginx está na versão 1.7.9
Para atualizar a imagem do container para 1.9.1 iremos usar o kubectl rolling-update e especificar a nova imagem.
```bash
$ kubectl set image deployments/my-nginx nginx=nginx:1.9.1
	
```
Em outra janela, você pode ver que o kubectl adicionou o label do deployment para os pods, que o valor é um hash da configuração, para distinguir os pods novos dos velhos
```bash
$ kubectl get pods -l app=nginx -L deployment
```













# Aula 18 - Autoscaling

### Autoscaling

Iremos executar o tutorial oficial para autoscaling.

https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/#before-you-begin

Para isso iremos rodar e expor o php-apache server

Desabilitar o monitoramento com prometheus e Grafana para o Autoscaling poder funcionar.


```bash
$ kubectl apply -f php-apache.yml
```

Agora iremos fazer a criação do Pod Autoscaler

```bash
$ kubectl apply -f hpa.yml
```

Iremos pegar o HPA

```bash
$ kubectl get hpa
```

### Autoscaling - Aumentar a carga

Agora iremos aumentar a carga no pod contendo o apache em php.

```bash
$ kubectl run -i --tty load-generator --image=busybox /bin/sh
# Hit enter for command prompt
$ while true; do wget -q -O- http://php-apache.default.svc.cluster.local; done
```

Agora iremos em outro terminal, com o kubectl, verificar como está o HPA, e também no painel do Rancher. 

```bash 
$ kubectl get hpa
$ kubectl get deployment php-apache
```











# Aula 19 - Scheduling

### LABEL E SELETORES

Nesse exercício iremos colocar o label disktype, com valor igual a "ssd" no nó B do nosso cluster. 
Esse exercício serve para demonstrar como podemos usar o kubernetes para organizar onde irão rodar os containers. Neste exemplo estamos usando disco SSD em 1 máquina, poderia ser ambiente diferente, recursos de rede diferentes também, etc.

```bash
$ kubectl get nodes 
$ kubectl label nodes <your-node-name> disktype=ssd

$ kubectl apply -f node-selector.yml

# remover o Label do node
$ kubectl label nodes k8s-1 disktype-
```










# Aula 20 - Pipeline

### Construção de Pipeline e rancher-yml para deployment. Pegar o exemplo.


### 1 - Fazer fork do repositório.

https://github.com/jonathanbaraldi/kubernetes-deploy-go

Você deve fazer um fork dos repositórios, ou criar os seus usando os arquivos como exeplo.

### 2 - Habilitar Pipeline

Habilitar o Pipeline dentro do Rancher, e usar os repositórios abaixo na demonstração.

Habilitar o Pipeline dentro do Rancher, e fazer uma alteração no código-fonte, fazendo um push para o repositório.

### 3 - Alterar código-fonte

Acompanhar todo o deployment. 

https://github.com/jonathanbaraldi/kubernetes-deploy-jboss









# Aula 21 - Kubeless


### Kubeless

https://kubeless.io

Para instalar o Kubeless em nosso cluster, iremos rodar os comandos abaixo.

```bash
$ export RELEASE=$(curl -s https://api.github.com/repos/kubeless/kubeless/releases/latest | grep tag_name | cut -d '"' -f 4)
$ kubectl create ns kubeless
$ kubectl create -f https://github.com/kubeless/kubeless/releases/download/$RELEASE/kubeless-$RELEASE.yaml

$ kubectl get pods -n kubeless
NAME                                           READY     STATUS    RESTARTS   AGE
kubeless-controller-manager-567dcb6c48-ssx8x   1/1       Running   0          1h

$ kubectl get deployment -n kubeless
NAME                          DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubeless-controller-manager   1         1         1            1           1h

$ kubectl get customresourcedefinition
NAME                          AGE
cronjobtriggers.kubeless.io   1h
functions.kubeless.io         1h
httptriggers.kubeless.io      1h
```

Depois de instalado no cluster, iremos agora instalar a linha de comando no mesmo local onde usamos nosso kubectl.

```bash
$ export OS=$(uname -s| tr '[:upper:]' '[:lower:]')

# Baixar o UNZIP
$ apt install unzip

$ cd /opt
$ curl -OL https://github.com/kubeless/kubeless/releases/download/$RELEASE/kubeless_$OS-amd64.zip && unzip kubeless_$OS-amd64.zip && sudo mv bundles/kubeless_$OS-amd64/kubeless /usr/local/bin/
```

Para verificar se foi instalado corretamente, iremos rodar:

```bash
$ kubeless function ls
```

### Kubeless - Função exemplo

Para fazer o deploy da função, iremos usar o arquivo de modelo exemplo **test.py** 

```bash
$ kubeless function deploy hello --runtime python2.7 --from-file test.py --handler test.hello
$ kubectl get functions
$ kubeless function ls
```

Para chamar a função podemos fazer da seguinte forma:
```bash
$ kubeless function call hello --data 'Hello world!'
```


Agora iremos aplicar a função através do arquivo YML, contendo todos os dados da função

```bash
$ kubectl apply -f function-nodejs.yml
```

### Kubeless UI 

https://github.com/kubeless/kubeless-ui

O Kubeless possui uma UI para facilitar a operação. Para instalar ela, iremos rodar:

```bash
$ kubectl create -f https://raw.githubusercontent.com/kubeless/kubeless-ui/master/k8s.yaml
```

Na interface do Rancher, iremos acessar pelo IP:PORTA no qual a UI foi instalada. E iremos executar alguns exemplos para entender seu funcionamento.




# Aula 22 - Helm


### HELM


```bash 
$ curl -LO https://git.io/get_helm.sh
$ chmod 700 get_helm.sh
$ ./get_helm.sh
$ helm init
$ helm init --upgrade


$ kubectl create serviceaccount --namespace kube-system tiller
$ kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
$ kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'


$ helm search

$ helm repo update

$ helm install stable/redis
```

As aplicações no catálogo do Rancher são feitas pelo Helm.


# Aula 23 - Como construir uma estratégia de containers Enterprise.

