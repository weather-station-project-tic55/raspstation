#!/usr/bin/python3
# -*- coding: utf-8 -*-

import os
import time
import statistics
import pymysql
import logging
import board
import smbus2
import bme280
import socket
import uuid

# sensorscript v2

# ============================================
# LEITURA DO RCID (ID DA ESTACAO)
# ============================================
def get_rcid():
    try:
        path = os.path.expanduser("~/.config/station/rcid.txt") 
        with open(path, "r") as f:
            return int(f.read().strip())
    except Exception as e:
        print(f"Erro ao ler rcID: {e}")
        return None
    
# I2C
bus = smbus2.SMBus(1)

# --- INICIALIZAÇÃO E TESTE DOS SENSORES ---
HAS_BME280 = False
HAS_BH1750 = False

# Tenta inicializar BME280
try:
    bme280_addr = 0x76
    bme280.load_calibration_params(bus, bme280_addr)
    HAS_BME280 = True
    print("[OK] BME280 detectado.")
except Exception:
    print("[AVISO] BME280 não encontrado.")

# Tenta inicializar BH1750 (fazendo uma escrita simples de teste)
try:
    bh1750_addr = 0x23
    bh1750_mode = 0x10 
    bus.write_byte(bh1750_addr, bh1750_mode)
    HAS_BH1750 = True
    print("[OK] BH1750 detectado.")
except Exception:
    print("[AVISO] BH1750 não encontrado.")

# Se nenhum sensor estiver conectado, encerra o script
if not HAS_BME280 and not HAS_BH1750:
    print("ERRO CRÍTICO: Nenhum sensor detectado no barramento I2C. Abortando...")
    exit(1)

# ============================================
# FUNÇÕES DE LEITURA
# ============================================
def read_bme280():
    if not HAS_BME280:
        return None
    try:
        data = bme280.sample(bus, bme280_addr) 
        return data.temperature, data.humidity, data.pressure
    except Exception as e:
        logging.error(f"Erro na leitura do BME280: {e}")
        return None

def read_bh1750():
    if not HAS_BH1750:
        return None
    try:
        data = bus.read_i2c_block_data(bh1750_addr, bh1750_mode, 2)
        raw = (data[0] << 8) | data[1]
        return raw / 1.2
    except Exception as e:
        logging.error(f"Erro na leitura do BH1750: {e}")
        return None
# ============================================
# FILTRO DE VALORES INVALIDOS
# ============================================
def is_valid(temp, hum, press, lux):
    if temp is not None and (temp < -30 or temp > 70):
        return False
    if hum is not None and (hum < 0 or hum > 100):
        return False
    if press is not None and (press < 800 or press > 1200):
        return False
    if lux is not None and lux < 0:
        return False
    return True
# ============================================
# CONEXAO COM O BANCO MARIADB
# ============================================
# PLACEHOLDERS SERÃO SUBSTITUÍDOS PELO INSTALADOR
DB_HOST = "DB_HOST_PLACEHOLDER"
DB_USER = "DB_USER_PLACEHOLDER"
DB_PASS = "DB_PASS_PLACEHOLDER"
DB_NAME = "DB_NAME_PLACEHOLDER"

def db_connect():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME
    )
    
# ============================================
# LOOP PRINCIPAL DE COLETA
# ============================================
def main():

    rcID = get_rcid()
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    logging.info("Iniciando coleta...")

    if rcID is None:
        logging.error("rcID not found")
        return
# ============================================
# CONSULTANDO O IP e MAC DA RASPBERRY
# ============================================
# --- BUSCA IP E MAC ATUAIS ---
    mac_atual = "{:012X}".format(uuid.getnode())
    
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    ip_atual = s.getsockname()[0]
    s.close()

    # --- COMPARA E ATUALIZA ---
    try:
        conn = db_connect()
        cursor = conn.cursor()
        cursor.execute("SELECT IP, MAC FROM raspclient WHERE rcID = %s", (rcID,))
        db_data = cursor.fetchone()

        # Se for diferente, atualiza
        if not db_data or (ip_atual != db_data[0] or mac_atual != db_data[1]):
            cursor.execute("UPDATE raspclient SET IP = %s, MAC = %s WHERE rcID = %s", 
                          (ip_atual, mac_atual, rcID))
            conn.commit()
            logging.info(f"IP e MAC da estação: {ip_atual} | {mac_atual}")
        
        conn.close()
    except Exception as e:
        logging.error(f"Erro na sincronização: {e}")

    m_temp = []
    m_hum = []
    m_press = []
    m_lux = []

    last_send = time.time()

    while True:
        # ----- LEITURA -----
        bme = read_bme280()
        lux = read_bh1750()

        if bme is not None:
            temp, hum, press = bme
        else:
            temp, hum, press = None, None, None
        
        

        # ----- Validacao -----
       
        if is_valid(temp, hum, press,lux):
            if temp is not None:
             m_temp.append(temp)
            if hum is not None:
             m_hum.append(hum)
            if press is not None:
             m_press.append(press)
            if lux is not None:
             m_lux.append(lux)
          

        # ----- A CADA 5 MINUTOS -----
        if time.time() - last_send >= 300:
            has_data = any([m_temp, m_hum, m_press, m_lux])

            if has_data:

                avg_temp = round(statistics.mean(m_temp), 2) if m_temp else None
                avg_hum = round(statistics.mean(m_hum), 2) if m_hum else None
                avg_press = round(statistics.mean(m_press), 2) if m_press else None
                avg_lux = round(statistics.mean(m_lux), 2) if m_lux else None

                try:
                    conn = db_connect()
                    cursor = conn.cursor()
                
                    cursor.execute(
                        """
                        INSERT INTO Raspdata (rcID, Temp, Humidity, Pressure, Lux)
                        VALUES (%s, %s, %s, %s, %s)
                        """,
                        (rcID, avg_temp, avg_hum, avg_press, avg_lux)
                    )
                    conn.commit()
                    conn.close()

                    logging.info(
                        f"Dados registrados: T={avg_temp} H={avg_hum} P={avg_press} L={avg_lux}"
                    )

                except Exception as e:
                    logging.error(f"Erro ao inserir no banco: {e}")

            else:
                logging.warning("Nenhuma leitura valida nos ultimos 5 minutos.")

            # reset dos buffers
            m_temp.clear()
            m_hum.clear()
            m_press.clear()
            m_lux.clear()
            last_send = time.time()

        time.sleep(10)

if __name__ == "__main__":
    main()
