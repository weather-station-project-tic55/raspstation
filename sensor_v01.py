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

# ============================================
# LEITURA DO RCID (ID DA ESTACAO)
# ============================================
# def get_rcid():
  #  try:
   #     path = os.path.expanduser("~/.config/station/rcid.txt") 
    #    with open(path, "r") as f:
     #       return int(f.read().strip())
    #except Exception as e:
     #   print(f"Erro ao ler rcID: {e}")
      #  return None
        

rcID = 1

# ============================================
# PARÂMETROS DO SENSOR
# ============================================
port = 1
address = 0x76
bus = smbus2.SMBus(port)
bme280.load_calibration_params(bus, address)

# ============================================
# FUNÇÃO DE LEITURA DO BME280
# ============================================
def read_bme280():
    try:
        # A leitura ocorre aqui
        data = bme280.sample(bus, address) 
        temp = data.temperature
        hum = data.humidity
        press = data.pressure
        return temp, hum, press
    except Exception as e:
        logging.error(f"Erro na leitura do BME280: {e}")
        return None
        
# ============================================
# FILTRO DE VALORES INVALIDOS (Luminosidade removida)
# ============================================
def is_valid(temp, hum, press):
    if temp is None or temp < -40 or temp > 85: # Limites técnicos do sensor
        return False
    if hum is None or hum < 0 or hum > 100:
        return False
    if press is None or press < 800 or press > 1100: # Limites razoáveis
        return False
    return True

# ============================================
# CONEXAO COM O BANCO MARIADB
# ============================================
# PLACEHOLDERS SERÃO SUBSTITUÍDOS PELO INSTALADOR
#DB_HOST = "DB_HOST_PLACEHOLDER"
#DB_USER = "DB_USER_PLACEHOLDER"
#DB_PASS = "DB_PASS_PLACEHOLDER"
#DB_NAME = "DB_NAME_PLACEHOLDER"

def db_connect():
    return pymysql.connect(
        host='192.168.100.3',
        user='root',
        password='ncssp',
        database='weatherdb'
    )
    
# ============================================
# LOOP PRINCIPAL DE COLETA
# ============================================
def main():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    logging.info("Iniciando coleta real...")

    m_temp = []
    m_hum = []
    m_press = []

    last_send = time.time()

    while True:
        # ----- LEITURA REAL -----
        bme = read_bme280()

        if bme is not None:
            temp, hum, press = bme
        else:
            temp, hum, press = None, None, None

        # ----- Validacao -----
       
        if is_valid(temp, hum, press):
            m_temp.append(temp)
            m_hum.append(hum)
            m_press.append(press)
          

        # ----- A CADA 5 MINUTOS -----
        if time.time() - last_send >= 300:
            if len(m_temp) > 0:

                avg_temp = round(statistics.mean(m_temp), 2)
                avg_hum = round(statistics.mean(m_hum), 2)
                avg_press = round(statistics.mean(m_press), 2)

                try:
                    conn = db_connect()
                    cursor = conn.cursor()
                
                    cursor.execute(
                        """
                        INSERT INTO Raspdata (rcID, Temp, Humidity, Pressure)
                        VALUES (%s, %s, %s, %s)
                        """,
                        (rcID, avg_temp, avg_hum, avg_press)
                    )
                    conn.commit()
                    conn.close()

                    logging.info(
                        f"Dados registrados: T={avg_temp} H={avg_hum} P={avg_press}"
                    )

                except Exception as e:
                    logging.error(f"Erro ao inserir no banco: {e}")

            else:
                logging.warning("Nenhuma leitura valida nos ultimos 5 minutos.")

            # reset dos buffers
            m_temp.clear()
            m_hum.clear()
            m_press.clear()
            # m_lum.clear() removida
            last_send = time.time()

        time.sleep(10)

if __name__ == "__main__":
    main()
