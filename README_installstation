Instalador automatizado para configurar uma estação de coleta de dados meteorológicos (BME280) em um Raspberry Pi e enviar os dados para um banco de dados MariaDB/MySQL central.

Este script Bash gerencia todas as dependências de software, ativa o I2C, configura as credenciais do banco e instala o script de coleta como um serviço Systemd para garantir a execução contínua.

- Funcionalidades Principais

Instalação de Dependências: Instala clientes MariaDB, Python e bibliotecas I2C.

Configuração de Hardware: Ativa automaticamente a interface I2C via raspi-config.

Persistência de Dados: Identifica o Raspberry Pi via Serial da CPU e armazena/recupera o rcID do banco de dados central.

Injeção Segura de Credenciais: As credenciais do banco são injetadas diretamente no script Python para conexão.

Serviço Systemd: Instala o script de coleta (sensor_v01.py) como um serviço (raspcollect.service) para rodar automaticamente no boot.

Desinstalação Limpa: Opção para remover o serviço e todos os arquivos de configuração.

- Pré-requisitos

Hardware: Um Raspberry Pi (qualquer modelo moderno) + sensores

Software: Raspberry Pi OS (ou Raspbian) instalado.

Acesso ao Banco de Dados: Um servidor MariaDB ou MySQL acessível via rede, com um banco de dados com as tabelas raspclient e Raspdata criadas.

- Uso
Execute o instalador no terminal da Raspberry Pi. O instalador deve estar na mesma pasta que o script de coleta (sensor_v01.py) e o arquivo de serviço (raspcollect.service).

Bash

# Navegue até o diretório do instalador

cd /caminho/para/seu/instalador

# Execute com sudo para permitir instalações e ativação de serviços

sudo /bin/bash install_station.sh

- Menu Interativo

O script apresentará duas opções:

Instalar o Raspberry Station: Inicia o processo de instalação, solicitando as credenciais de conexão do banco de dados e dados da estação.

Desinstalar (Remover serviço e arquivos): Remove o serviço Systemd e todos os arquivos gerados no diretório do usuário (~/.config/station).

- Detalhes da Instalação

Durante a instalação, o script fará as seguintes perguntas:

Credenciais do Banco: IP, Usuário, Senha e Nome do Banco de Dados.

Informações da Estação: Nome, Latitude, Longitude, Altitude, Local, Email e Contato.
