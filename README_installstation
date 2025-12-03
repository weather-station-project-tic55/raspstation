Este documento detalha o funcionamento e os blocos de código do script de instalação em Bash, installstation_v01.sh.
O objetivo deste script é configurar uma Raspberry Pi para coleta de dados, incluindo a instalação de dependências, configuração do I2C, registro no banco de dados
e ativação do serviço de coleta.

🧱 1. Configurações de Diretório

set -e
# ===========================================
# CONFIGURAÇÕES DE DIRETÓRIO
# ===========================================
STATION_DIR="/home/$SUDO_USER/.config/station"
COLLECT_SCRIPT="main_mocked_v01.py" # Usando a versão mockada
SERVICE="raspcollect.service"
SERVICE_DIR="/etc/systemd/system/$SERVICE"
# Diretório do script atual para encontrar os arquivos a serem copiados
INSTALLER_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
# ...

set -e: Garante que o script pare imediatamente se qualquer comando retornar um código de erro diferente de zero.

Variáveis de Caminho: Define o diretório de instalação (STATION_DIR - dentro de .config/station do usuário que executou o sudo), nomes dos arquivos do script de coleta e do serviço.

$SUDO_USER: Variável essencial que armazena o nome do usuário que iniciou o script com sudo, permitindo que os arquivos de configuração e o serviço sejam configurados corretamente para ele.

INSTALLER_DIR: Obtém o caminho absoluto do diretório onde o script installstation_v01.sh está localizado, permitindo que ele encontre e copie os outros arquivos (.py e .service).

🧱 2. Input de Conexão com Banco (Validação em Loop)
Bash

# ===========================================
# 1) INPUT DE CONEXÃO COM BANCO
# ===========================================
# ...
while true; do
    # Exibe mensagem de erro se não for a primeira tentativa
    if [ "$FIRST_ATTEMPT" = "false" ]; then # ... ❌ FALHA NA CONEXÃO!
    fi
    
    # --- Coleta de Dados ---
    read -p "IP/Host do banco... " DB_HOST
    read -s -p "Senha do banco... " DB_PASS # Oculta a senha (read -s)
    # ...

if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" --skip-column-names --skip-ssl -e ";" 2>/dev/null; 

then 
        echo "✅ CONEXÃO ESTABELECIDA!"
        break # Sai do loop
fi
    FIRST_ATTEMPT="false" # Marca para exibir erro na próxima
done
# ...

Validação Crucial: Este bloco é um loop infinito (while true) que só é interrompido por um break após uma conexão bem-sucedida com o banco de dados.

Coleta Interativa: Usa o comando read -p para solicitar as credenciais ao usuário. O read -s é usado para a senha (DB_PASS), garantindo que ela não seja exibida na tela.

Teste de Conexão: A condição if mysql -h ... -e ";" tenta executar um comando SQL vazio. Se o comando retornar código de saída 0 (sucesso), significa que as credenciais são válidas e o script continua.

Tratamento de Erros: 2>/dev/null suprime as mensagens de erro do mysql (ex: "Access denied") do console, mantendo a saída limpa. Se o teste falhar, a variável FIRST_ATTEMPT é marcada, e o loop solicita as informações novamente, exibindo o erro.

🧱 3. Instalação de Dependências de Sistema e I2C

# ===========================================
# INSTALAR DEPENDÊNCIAS DO SISTEMA (1/10)
# ===========================================
echo "--- 1/10 Instalando dependências do sistema... ---"
sudo apt update
sudo apt install -y python3 python3-pip python3-smbus i2c-tools

# ===========================================
#  HABILITAR I2C NO SISTEMA (2/10)
# ===========================================
echo "--- 2/10 Ativando I2C... ---"
sudo raspi-config nonint do_i2c 0
                                                  
Atualização e Instalação: Usa sudo apt para atualizar a lista de pacotes e instalar ferramentas essenciais como python3, pip (gerenciador de pacotes Python) e i2c-tools (para diagnóstico I2C).

Habilitação do I2C: O comando sudo raspi-config nonint do_i2c 0 é um comando de sistema que habilita programaticamente a interface I2C na Raspberry Pi, que é necessária para comunicação com o sensor BME280.

🧱 4. Instalação de Bibliotecas Python

# ===========================================
#  INSTALAR BIBLIOTECAS DO SENSOR (3/10)
# ===========================================
echo "--- 3/10 Instalando bibliotecas Python do BME280... ---"
sudo pip3 install --break-system-packages adafruit-circuitpython-bme280 adafruit-blinka pymysql
                                                  
Bibliotecas Essenciais: Instala as bibliotecas Python necessárias para o script de coleta:

adafruit-circuitpython-bme280: Driver para comunicação com o sensor BME280.

adafruit-blinka: Biblioteca que fornece a camada de compatibilidade do CircuitPython (Adafruit) em placas como a Raspberry Pi.

pymysql: Driver Python para se conectar e interagir com o banco de dados MySQL/MariaDB.

--break-system-packages: É uma flag usada em ambientes Debian/Raspberry Pi OS mais recentes que permite a instalação de pacotes Python diretamente no sistema, contornando a proteção do gerenciamento de pacotes do sistema.

🧱 5. Identificação e Registro do MAC Address/RCID

# ===========================================
#  IDENTIFICAR MAC ADDRESS (4/10)
# ===========================================
# ...
MAC=$(cat /sys/class/net/eth0/address | tr -d '\n')

# ===========================================
#  CONSULTAR/CRIAR RCID NO BANCO (5/10)
# ===========================================
# Função auxiliar para executar comandos SQL
SQL_COMMAND() { # ... }

# Consulta o rcID
RCID=$(SQL_COMMAND "SELECT rcID FROM raspclient WHERE mac='$MAC' LIMIT 1;")

if [ -z "$RCID" ]; then
    echo ">>> MAC não encontrado. Criando novo registro..."
    SQL_COMMAND "INSERT INTO raspclient (mac) VALUES ('$MAC');"
    RCID=$(SQL_COMMAND "SELECT rcID FROM raspclient WHERE mac='$MAC' LIMIT 1;") # Recupera o novo ID
# ...
else
    echo ">>> MAC já existe. rcID encontrado: $RCID"
fi
  
Obtenção do MAC: Lê o endereço MAC da interface de rede eth0 e remove quebras de linha. Este MAC é usado como identificador único da estação.

Função SQL_COMMAND: Cria uma função de shell para simplificar a execução de comandos SQL no banco de dados usando as credenciais informadas anteriormente.

Lógica de Registro:

Consulta se o MAC já existe na tabela raspclient para obter o rcID.

Se RCID estiver vazio ([ -z "$RCID" ]), insere o novo MAC e consulta novamente para obter o rcID recém-criado (Chave primária AUTO_INCREMENT).

Se RCID for encontrado, ele é atribuído e o script segue adiante.

🧱 6. Criação de Diretórios e Salvamento do RCID Local


# ===========================================
#  CRIAR DIRETÓRIOS E ARQUIVO RCID.TXT (6/10)
# ===========================================
echo "--- 6/10 Criando diretórios e salvando rcID... ---"

mkdir -p "$STATION_DIR"

# Salvar rcID no diretório ~/.config/station/rcid.txt
echo "$RCID" > "$STATION_DIR/rcid.txt"

Criação do Diretório: mkdir -p cria o diretório de configuração do usuário (~/.config/station), garantindo que ele não gere erro se o diretório já existir.

Armazenamento Local do RCID: O rcID (identificador da estação) é salvo no arquivo rcid.txt. O script de coleta (main_mocked_v01.py) usará este arquivo para saber qual é o seu ID ao enviar dados para o banco.

🧱 7. Input e Atualização dos Metadados da Estação

# ===========================================
# INPUT E UPDATE DA raspclient (7/10)
# ===========================================
echo "--- 7/10 Informações adicionais da estação (UPDATE)... ---"

read -p "Nome da estação: " NAME
# ... coleta de outras informações (Lat, Lng, etc.)

# Cria o comando de UPDATE, escapando aspas simples para segurança
UPDATE_QUERY="UPDATE raspclient SET \
name='$(echo "$NAME" | sed "s/'/''/g")', \
# ... outros campos
WHERE rcID='$RCID';"

# Executa o UPDATE

SQL_COMMAND "$UPDATE_QUERY"

Coleta de Metadados: Solicita informações descritivas da estação (Nome, Localização, Contato, etc.).

Comando de UPDATE: Monta a query SQL de UPDATE para a tabela raspclient usando o rcID como chave.

Segurança (Shell): O comando sed "s/'/''/g" é usado para escapar aspas simples dentro das strings fornecidas pelo usuário. Isso previne erros SQL e injeção SQL básica, garantindo que o UPDATE seja executado corretamente.

🧱 8. Cópia de Arquivos

# ===========================================
#  COPIAR SCRIPTS E SERVIÇO (8/10)
# ===========================================
echo "--- 8/10 Copiando scripts e serviço... ---"

# Copia o script de coleta
cp "$INSTALLER_DIR/$COLLECT_SCRIPT" "$STATION_DIR/$COLLECT_SCRIPT"
chmod 777 "$STATION_DIR/$COLLECT_SCRIPT" # Permissão full

# Copia o arquivo de serviço
sudo cp "$INSTALLER_DIR/$SERVICE" /etc/systemd/system/"$SERVICE"
sudo chmod 777 /etc/systemd/system/"$SERVICE" # Permissão full
Cópia dos Binários: Copia o script Python (main_mocked_v01.py) para o diretório de trabalho do usuário (~/.config/station/) e o arquivo de serviço (raspcollect.service) para o diretório do sistema (/etc/systemd/system/).

Permissões: Define permissões 777 (leitura, escrita e execução para todos) para garantir que o serviço systemd (que rodará como o usuário pi ou INSTALL_USER) possa executar o script e que o sistema possa acessar o arquivo de serviço.

🧱 9. Injeção da Configuração do Banco
Bash

# ===========================================
#  INJETAR CONFIGURAÇÃO DO BANCO NO PYTHON (9/10)
# ===========================================
echo "--- 9/10 Injetando credenciais no script de coleta... ---"

SCRIPT_TO_EDIT="$STATION_DIR/$COLLECT_SCRIPT"

# --- Injeção de Variáveis ---
# 1. Substitui o Host/IP
sudo sed -i "s|DB_HOST = \"DB_HOST_PLACEHOLDER\"|DB_HOST = \"$DB_HOST\"|g" "$SCRIPT_TO_EDIT"
# 2. Substitui o Usuário
# ...

# GARANTE QUE O SCRIPT PERTENÇA AO USUÁRIO FINAL
sudo chown "$SUDO_USER:$SUDO_USER" "$SCRIPT_TO_EDIT"
Edição In-Place: Este é um bloco crítico. Ele usa o comando sudo sed -i para substituir os placeholders (como "DB_HOST_PLACEHOLDER") dentro do script Python de coleta (main_mocked_v01.py) pelos valores reais de conexão ($DB_HOST, $DB_USER, etc.) fornecidos pelo usuário.

Sintaxe sed: A sintaxe s|old|new|g faz uma substituição global (g) de old por new. O caractere | é usado como delimitador para evitar conflitos com barras normais / que poderiam aparecer em caminhos de arquivo.

Propriedade (Ownership): sudo chown "$SUDO_USER:$SUDO_USER" garante que, mesmo que a edição tenha sido feita com sudo, o script Python pertença ao usuário final (pi, por exemplo), o que é importante para um serviço que roda no diretório home do usuário.

🧱 10. Recarregar e Ativar o Serviço Systemd
Bash

# ===========================================
#  RECARREGAR SYSTEMD E ATIVAR SERVIÇO (10/10)
# ===========================================
echo "--- 10/10 Ativando serviço de coleta... ---"
sudo sed -i "s|INSTALL_USER|$SUDO_USER|g" "$SERVICE_DIR"
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE"
sudo systemctl restart "$SERVICE"
# ...
Configuração do Usuário: O primeiro sed substitui o placeholder INSTALL_USER dentro do arquivo de serviço (raspcollect.service) pelo $SUDO_USER real. Isso garante que o script de coleta seja executado com as permissões e no ambiente correto do usuário.

systemctl daemon-reload: Informa ao gerenciador de serviços do Linux (systemd) que um novo arquivo de serviço foi adicionado ou modificado. É essencial após a cópia do arquivo .service.

systemctl enable: Habilita o serviço, garantindo que ele inicie automaticamente no boot do sistema.

systemctl restart: Inicia (ou reinicia, se já estiver rodando) o serviço imediatamente, finalizando o processo de instalação.
