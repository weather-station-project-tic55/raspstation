Raspstation collector v01
Este projeto contém os scripts de instalação e coleta de dados (atualmente mockados) para uma Raspberry Pi equipada com um sensor BME280 e um sensor de luminosidade, enviando os dados para um banco de dados MySQL/MariaDB.

Estrutura do Repositório:

O repositório é composto por três arquivos principais:

installstation_v03.sh - Instalador principal. Configura o ambiente, I2C, dependências, identifica e cadastra a estação no DB, ativa o serviço de coleta.

sensor_v01.py - Python Script de coleta de dados. Contém a lógica de leitura, agregação (média a cada 5 minutos) e envio para o banco.

raspcollect.service - Serviço Systemd. Garante que o script de coleta seja executado em background e reinicie automaticamente em caso de falha.

Requisitos
Hardware:

Raspberry Pi (testado no Raspberry Pi OS).

Acesso: Usuário com permissão sudo(linux).

Banco de Dados: Um servidor MySQL ou MariaDB acessível pela Raspberry Pi.

Tabelas: A base de dados deve conter as tabelas raspclient e Raspdata com a estrutura necessária.

Processo de Instalação

O instalador installstation_v01.sh automatiza todo o processo, desde a instalação de dependências até a ativação do serviço.

1- Executar o Instalador

O script deve ser executado com permissões de sudo para instalar dependências, configurar o I2C e criar o serviço no sistema.

comando: sudo ./installstation_v01.sh

3. Interação com o Instalador
   
O script solicitará as seguintes informações de forma interativa para a conexão com o Banco de Dados:

IP/Host do banco:

Usuário do banco:

Senha do banco (Oculta na digitação):

Nome do banco:

O instalador possui um loop de validação que testa a conexão do MySQL/MariaDB. Ele só prosseguirá se a conexão for bem-sucedida.

Informações da Estação (Metadados)

Após identificar ou criar o rcID no banco (raspclient), o script solicitará as seguintes informações de forma interativa:

############# AINDA FALTA UMA TRATATIVA PARA CASO O USUÁRIO INSIRA INFORMAÇÕES INADEQUADAS ################

Nome da estação:
Latitude:
Longitude:
Altitude (height):
Altitude nível do mar (height_sea_level):
Local/Endereço:
Email do responsável:
Contato:

#############################################################################################################

4. O que o Instalador Faz (Passos Principais)

Instala Dependências: python3, pip, i2c-tools e bibliotecas Python (adafruit-bme280, adafruit-blinka, pymysql).

Configura I2C: Ativa o protocolo I2C via raspi-config.

Registro no DB: Detecta o serial da CPU da Rasp

Se o serial da CPU existe na tabela raspclient, recupera o rcID.

Se o serial da CPU não existe, cria um novo registro e obtém o novo rcID.

Configura Diretórios: Cria o diretório de trabalho ~/.config/station e salva o rcID no arquivo rcid.txt.

Atualiza Metadados: Faz um UPDATE na tabela raspclient com os dados de localização fornecidos.

Injeta Credenciais: Edita o script main_mocked_v01.py para injetar as credenciais do DB (Host, User, Pass, Name) nos placeholders.

Instala e Ativa o Serviço: Copia o arquivo raspcollect.service para o systemd, recarrega e inicia o serviço.

Verificação do Status

Após a instalação, você pode verificar se o serviço de coleta está rodando corretamente usando o comando:

sudo systemctl status raspcollect.service

O script de coleta envia dados (mockados) para o banco a cada 5 minutos. Você pode verificar os logs para confirmar as inserções:

journalctl -u raspcollect.service -f
