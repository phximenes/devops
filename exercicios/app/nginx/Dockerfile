	# Setar a imagem do nginx
FROM nginx

	# Autor/Mantenedor
# MAINTAINER Pedro Ximenes

	# Copiar configurações customizadas do diretório atual
COPY nginx.conf /etc/nginx/nginx.conf

COPY certificado/certificado.crt  /etc/ssl/certificado.crt
COPY certificado/certificado.key  /etc/ssl/certificado.key
