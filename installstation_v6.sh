#!/bin/bash
set -e
# ===========================================
# CONFIGURAÇÕES DE DIRETÓRIO
# ===========================================
STATION_DIR="/home/$SUDO_USER/.config/station"
COLLECT_SCRIPT="sensorscript.py"
SERVICE="sensorcollect.service"
SERVICE_DIR="/etc/systemd/system/$SERVICE"
INSTALLER_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

echo "===== Instalador Raspberry Station v6 ====="
echo " "
# ===========================================
# FUNÇÃO: EDITAR CONFIGURAÇÕES DO BANCO
# ===========================================
edit_config() {
SCRIPT_TO_EDIT="/home/$SUDO_USER/.config/station/sensorscript.py"
echo "##### Configurações atuais #####"
echo " "
#### Exibe as configurações atuais ####
grep "DB_HOST =" "$SCRIPT_TO_EDIT"
grep "DB_USER =" "$SCRIPT_TO_EDIT"
grep "DB_PASS =" "$SCRIPT_TO_EDIT"
grep "DB_NAME =" "$SCRIPT_TO_EDIT"
echo " " 

    FIRST_ATTEMPT="true"
    while true; do
        if [ "$FIRST_ATTEMPT" = "false" ]; then
            echo -e "\n❌ FALHA NA CONEXÃO! Verifique os dados e tente novamente.\n"
        fi
        
        echo "##### Insira as novas configurações do Banco... #####"
        read -p "Digite o IP/Host do banco: " NEW_DBHOST
        read -p "Digite o usuário do banco: " NEW_DBUSER
        read -s -p "Digite a senha do banco (ao digitar não será visível): " NEW_DBPASS
        echo ""
        read -p "Digite o nome do banco: " NEW_DBNAME

        # Teste de conexão
        if mysql -h "$NEW_DBHOST" -u "$NEW_DBUSER" -p"$NEW_DBPASS" "$NEW_DBNAME" --skip-column-names --skip-ssl -e ";" 2>/dev/null;
        then 
            echo -e "\n✅ CONEXÃO ESTABELECIDA!"
            break 
        fi
        FIRST_ATTEMPT="false"
    done

    echo "##### Aplicando alterações... #####"
    sudo systemctl stop "$SERVICE"

    sudo sed -i "s|DB_HOST = .*|DB_HOST = \"$NEW_DBHOST\"|g" "$SCRIPT_TO_EDIT"
    sudo sed -i "s|DB_USER = .*|DB_USER = \"$NEW_DBUSER\"|g" "$SCRIPT_TO_EDIT"
    sudo sed -i "s|DB_PASS = .*|DB_PASS = \"$NEW_DBPASS\"|g" "$SCRIPT_TO_EDIT"
    sudo sed -i "s|DB_NAME = .*|DB_NAME = \"$NEW_DBNAME\"|g" "$SCRIPT_TO_EDIT"

    sudo systemctl start "$SERVICE"
    echo "✅ Configurações atualizadas e serviço reiniciado!"
}
# ===========================================
# FUNÇÃO DE DESINSTALAÇÃO
# ===========================================
uninstallstation() {
    echo "--- INICIANDO DESINSTALAÇÃO DO RASPBERRY STATION ---"

    # 1. Parar e desabilitar o serviço
    if  sudo systemctl is-active --quiet "$SERVICE"; then
        echo "1/3 Parando o serviço $SERVICE..."
        sudo systemctl stop "$SERVICE"
    fi
    if  sudo systemctl is-enabled --quiet "$SERVICE"; then
        echo "2/3 Desabilitando o serviço $SERVICE..."
        sudo systemctl disable "$SERVICE"
    fi

    # 2. Remover arquivos de serviço
    if [ -f "$SERVICE_DIR" ]; then
        echo "3/3 Removendo arquivo de serviço do sistema ($SERVICE_DIR)..."
        sudo rm -rf "$SERVICE_DIR"
        sudo systemctl daemon-reload
    fi
    
    # 3. Remover diretório de instalação do usuário
    if [ -d "$STATION_DIR" ]; then
        echo "Removendo diretório de scripts e configuração ($STATION_DIR)..."
        sudo rm -rf "$STATION_DIR"
    fi

    # 4. Remover registro da raspclient


    echo " "
    echo "✅ DESINSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    exit 0
}

# ===========================================
# MENU DE OPÇÕES INICIAL
# ===========================================
echo "===== Raspberry Station ====="
echo "1) Instalar"
echo "2) Desinstalar"
echo "3) Editar Configurações de Conexão com o Banco"
echo " "
read -p "Escolha uma opção: " OPTION

case $OPTION in
    1)
        echo "Iniciando a instalação..."
        # O código de instalação segue abaixo...
        ;;
    2)
        read -r -p "Confirmar desinstalação? (S/n) " CONFIRM
        [[ "$CONFIRM" =~ ^[Ss]$ ]] && uninstallstation || exit 0
        ;;
    3)
        edit_config
        exit 0
        ;;
    *)
        echo "Opção inválida."
        exit 1
        ;;
esac

sleep 2

# ===========================================
# INSTALAR DEPENDÊNCIAS DO SISTEMA
# ===========================================
echo "--- 1/9 Instalando dependências do sistema... ---"
sudo apt update
sudo apt install -y python3 python3-pip python3-smbus i2c-tools mariadb-client 
sudo pip3 install RPi.bme280 --break-system-packages pymysql #BME280
sudo apt install apache2-utils ### Biblioteca para criptografar a senha da estação
sleep 3

# ===========================================
#  HABILITAR I2C NO SISTEMA
# ===========================================
echo "--- 2/9 Ativando I2C... ---"
sudo raspi-config nonint do_i2c 0

sleep 3

# ===========================================
#  INPUT DE CONEXÃO COM BANCO
# ===========================================

FIRST_ATTEMPT="true"

while true; do

    # Se NÃO for a primeira tentativa, exibe o erro
    if [ "$FIRST_ATTEMPT" = "false" ]; 
    then
        echo " "
        echo "❌ FALHA NA CONEXÃO!"
        echo "Não foi possível conectar com os dados fornecidos."
        echo "Por favor, verifique as informações e tente novamente."
        echo " "
    fi
    
    # --- Coleta de Dados ---
    echo "Insira as informações de conexão com o banco:"
    echo " "
    read -p "IP/Host do banco (ex: 192.168.100.10): " DB_HOST
    read -p "Usuário do banco: " DB_USER
    read -s -p "Senha do banco: " DB_PASS
    echo
    read -p "Nome do banco: " DB_NAME

if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" --skip-column-names --skip-ssl -e ";" 2>/dev/null; 

then 
        echo " "
        echo "✅ CONEXÃO ESTABELECIDA!"
        break # Se for bem-sucedido (código 0), sai do loop
fi
# Se o teste falhou (o 'break' não foi executado), marca para mostrar o erro na próxima
    FIRST_ATTEMPT="false"

done

sleep 3

# ===========================================
#  IDENTIFICAR SERIAL DA CPU DA RASP
# ===========================================
echo "--- 3/9 Identificando ID da rasp (serial da cpu) ---"

# Tenta extrair o Serial da CPU do arquivo /proc/cpuinfo
# O serial é o identificador único e permanente da Raspberry Pi.
RCID_SERIAL=$(awk '/Serial/ {print $3}' /proc/cpuinfo)

if [ -z "$RCID_SERIAL" ]; then
    echo "ERRO: Não foi possível obter o Número de Série da CPU."
    echo "Verifique se o arquivo /proc/cpuinfo está disponível ou se o formato é o esperado."
    exit 1
fi

echo "Serial da CPU detectado: $RCID_SERIAL"

sleep 3

# ===========================================
#  CONSULTAR/CRIAR RCID NO BANCO
# ===========================================
echo "--- 4/9 Consultando/Criando Serial no banco... ---"

# Função auxiliar para executar comandos SQL
SQL_COMMAND() {
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    --skip-column-names --batch --skip-ssl \
    -e "$1"
}
# Consulta o rcID
RCID=$(SQL_COMMAND "SELECT rcID FROM raspclient WHERE serial='$RCID_SERIAL' LIMIT 1;")

if [ -z "$RCID" ]; then
    echo ">>> Serial não encontrado no banco. Criando novo registro..."

    # Insere o novo MAC
    SQL_COMMAND "INSERT INTO raspclient (serial) VALUES ('$RCID_SERIAL');"

    # Recupera o rcID recém-criado
    RCID=$(SQL_COMMAND "SELECT rcID FROM raspclient WHERE serial='$RCID_SERIAL' LIMIT 1;")

    if [ -z "$RCID" ]; then
        echo "Não foi possível criar ou recuperar o rcID após a inserção."
        exit 1
    fi
    echo ">>> Novo rcID criado: $RCID"
else
    echo ">>> Serial já existe. rcID encontrado: $RCID"
fi

sleep 3

# ===========================================
#  CRIAR DIRETÓRIOS E ARQUIVO RCID.TXT
# ===========================================
echo "--- 5/9 Criando diretórios e salvando rcID... ---"

mkdir -p "$STATION_DIR"

# Salvar rcID no diretório ~/.config/station/rcid.txt
echo "$RCID" > "$STATION_DIR/rcid.txt"
echo "rcID ($RCID) salvo em $STATION_DIR/rcid.txt"

sleep 3

# ===========================================
# INPUT E UPDATE DA raspclient
# ===========================================
echo "--- 6/9 Informações adicionais da estação... ---"

FIRST_ATTEMPT2="true"

while true; do

 # Se NÃO for a primeira tentativa, exibe o erro
if [ "$FIRST_ATTEMPT2" = "false" ]; 

 then
 echo " "
 echo "❌ FALHA NO INSERT"
 echo "Não foi possível cadastrar a estação com os dados fornecidos."
 echo " "
 echo "Por favor, verifique as informações inseridas estão de acordo com o previsto:"
 echo " "
 echo "Nome da estação - SOMENTE LETRAS E CARACTERES"
 echo "Latitude  - SOMENTE NÚMEROS E (.) COMO SEPARADOR"
 echo "Longitude - SOMENTE NÚMEROS E (.) COMO SEPARADOR"
 echo "Altitude  - SOMENTE NÚMEROS E (.) COMO SEPARADOR"
 echo "Altitude com relação ao nível do mar - SOMENTE NÚMEROS E (.) COMO SEPARADOR"
 echo "Local/Endereço - LETRAS, NÚMEROS E CARACTERES"
 echo "Email do responsável - LETRAS, NÚMEROS E CARACTERES"
 echo "Contato - NÚMEROS E CARACTERES"
 echo "Evite caracteres como '(''' '"' "--" "\0"  "<"  ">")'
 echo " "

 fi

read -p "Nome da estação: " NAME
read -p "Latitude: " LAT
read -p "Longitude: " LNG
read -p "Altitude (metros): " HEIGHT
read -p "Altitude com relação ao nível do mar (metros): " HSL
read -p "Local/Endereço: " LOCATION
read -p "Contato: " CONTACT
read -p "Email para login: " EMAIL
read -s -p "Senha para login: " PASSLOGIN
echo
read -s -p "Confirme a senha: " PASSLOGIN2


FIRST_ATTEMPT_LOGIN="true"

if [ "$PASSLOGIN" != "$PASSLOGIN2" ]; then
  echo "As senhas não conferem, tente novamente."
  FIRST_ATTEMPT_LOGIN="false"
fi

while [ "$FIRST_ATTEMPT_LOGIN" = "false" ]; do
read -s -p "Senha para login: " PASSLOGIN
echo
read -s -p "Confirme a senha: " PASSLOGIN2
echo

if [ "$PASSLOGIN" = "$PASSLOGIN2" ]; then
  FIRST_ATTEMPT_LOGIN="true"
else
    echo "As senhas não conferem, tente novamente."
fi  
done

HASHPASSWORD=$(htpasswd -nbBC 12 rasp "$PASSLOGIN" | cut -d ':' -f2) ### Criptografia da senha

UPDATE_QUERY="UPDATE raspclient SET \
name='$(echo "$NAME" | sed "s/'/''/g")', \
latitude='$LAT', longitude='$LNG', \
height='$HEIGHT', height_sea_level='$HSL', \
local='$(echo "$LOCATION" | sed "s/'/''/g")', \
email='$EMAIL', contact='$CONTACT', \
password= '$HASHPASSWORD' \
WHERE rcID='$RCID';"

# Executa o comando de update
if (SQL_COMMAND "$UPDATE_QUERY"); 
    then 
 echo " "
 echo "✅ ESTAÇÃO CADASTRADA!"
 break # Sai do loop
    fi
    # Se o 'if' acima falhar é sinal que o insert no banco deu errado

    FIRST_ATTEMPT2="false"
done

sleep 3

echo ">>> Dados atualizados no banco com sucesso para o rcID: $RCID."

# ===========================================
#  COPIAR SCRIPTS E SERVIÇO
# ===========================================
echo "--- 7/9 Copiando scripts e serviço... ---"

# Copia o script de coleta
cp "$INSTALLER_DIR/$COLLECT_SCRIPT" "$STATION_DIR/$COLLECT_SCRIPT"
# Permissão full para o script
chmod 777 "$STATION_DIR/$COLLECT_SCRIPT"
echo "Script de coleta copiado para $STATION_DIR/$COLLECT_SCRIPT e permissão full concedida."

sleep 3

# Copia o arquivo de serviço
sudo cp "$INSTALLER_DIR/$SERVICE" /etc/systemd/system/"$SERVICE"
# Permissão full para o serviço
sudo chmod 777 /etc/systemd/system/"$SERVICE"
echo "Arquivo de serviço copiado para /etc/systemd/system/$SERVICE e permissão full concedida."

sleep 3

# ==================================================
#  INJETAR CONFIGURAÇÃO DO BANCO NO SCRIPT DE COLETA
# ==================================================
echo "--- 8/9 Injetando configurações no script de coleta... ---"

# Caminho absoluto do script copiado que precisa ser editado (no diretório do usuário)
SCRIPT_TO_EDIT="$STATION_DIR/$COLLECT_SCRIPT"

# --- Injeção de Variáveis ---
# O comando sed busca o placeholder literal (e as aspas) e substitui pelo valor validado.

# 1. Substitui o Host/IP
sudo sed -i "s|DB_HOST = \"DB_HOST_PLACEHOLDER\"|DB_HOST = \"$DB_HOST\"|g" "$SCRIPT_TO_EDIT"

# 2. Substitui o Usuário
sudo sed -i "s|DB_USER = \"DB_USER_PLACEHOLDER\"|DB_USER = \"$DB_USER\"|g" "$SCRIPT_TO_EDIT"

# 3. Substitui a Senha
sudo sed -i "s|DB_PASS = \"DB_PASS_PLACEHOLDER\"|DB_PASS = \"$DB_PASS\"|g" "$SCRIPT_TO_EDIT"

# 4. Substitui o Nome do Banco
sudo sed -i "s|DB_NAME = \"DB_NAME_PLACEHOLDER\"|DB_NAME = \"$DB_NAME\"|g" "$SCRIPT_TO_EDIT"

# GARANTE QUE O SCRIPT PERTENÇA AO USUÁRIO FINAL
sudo chown "$SUDO_USER:$SUDO_USER" "$SCRIPT_TO_EDIT"

echo "Configurações injetadas em $SCRIPT_TO_EDIT."

sleep 3
# ===========================================
#  RECARREGAR SYSTEMD E ATIVAR SERVIÇO
# ===========================================
echo "--- 9/9 Ativando serviço de coleta... ---"
sudo sed -i "s|INSTALL_USER|$SUDO_USER|g" "$SERVICE_DIR"
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE"
sudo systemctl restart "$SERVICE"

echo "===== INSTALAÇÃO FINALIZADA COM SUCESSO! ====="
echo "rcID instalado: $RCID"
echo "Para verificar o status do serviço, execute: sudo systemctl status $SERVICE"
