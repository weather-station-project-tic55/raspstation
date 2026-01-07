#!/usr/bin/python3
# -*- coding: utf-8 -*-
# ======= TODAS AS LEITURAS MOCKADAS ======

import os
import time
import statistics
import pymysql
import logging
import random

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
# ============================================
# MOCK DO SENSOR BME280
# ============================================

def read_bme280():
    """
    Mock de temperatura, umidade e pressao
    """
    try:
        temp = random.uniform(-5, 40)
        hum = random.uniform(10, 95)
        press = random.uniform(900, 1050)
        return temp, hum, press
    except Exception as e:
        logging.error(f"Erro no mock do BME280: {e}")
        return None

# ============================================
# MOCK DE SENSOR DE LUMINOSIDADE
# ============================================
def read_luminosity():
    return random.uniform(0, 1000)

# ============================================
# FILTRO DE VALORES INVALIDOS
# ============================================
def is_valid(temp, hum, press, lum):
    if temp is None or temp == 0 or temp < -20 or temp > 50:
        return False
    if hum is None or hum == 0 or hum > 100:
        return False
    if press is None or press < 800 or press > 1100:
        return False
    if lum is None or lum < 0 or lum > 200000:
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
    logging.info("Iniciando...")

    rcID = get_rcid()
    if rcID is None:
        logging.error("rcID not found")
        return

    m_temp = []
    m_hum = []
    m_press = []
    m_lum = []

    last_send = time.time()

    while True:
        # ----- MOCK -----
        bme = read_bme280()
        luminosity = read_luminosity()

        if bme is not None:
            temp, hum, press = bme
        else:
            temp, hum, press = None, None, None

        # ----- Validacao -----
        if is_valid(temp, hum, press, luminosity):
            m_temp.append(temp)
            m_hum.append(hum)
            m_press.append(press)
            m_lum.append(luminosity)

        # ----- A CADA 5 MINUTOS -----
        if time.time() - last_send >= 300:
            if len(m_temp) > 0:

                avg_temp = round(statistics.mean(m_temp), 2)
                avg_hum = round(statistics.mean(m_hum), 2)
                avg_press = round(statistics.mean(m_press), 2)
                avg_lum = round(statistics.mean(m_lum), 2)

                try:
                    conn = db_connect()
                    cursor = conn.cursor()
                    cursor.execute(
                        """
                        INSERT INTO Raspdata (rcID, Temp, Humidity, Pressure, Light)
                        VALUES (%s, %s, %s, %s, %s)
                        """,
                        (rcID, avg_temp, avg_hum, avg_press, avg_lum)
                    )
                    conn.commit()
                    conn.close()

                    logging.info(
                        f"Mock registrado: T={avg_temp} H={avg_hum} P={avg_press} L={avg_lum}"
                    )

                except Exception as e:
                    logging.error(f"Erro ao inserir no banco: {e}")

            else:
                logging.warning("Nenhuma leitura valida nos ultimos 5 minutos.")

            # reset dos buffers
            m_temp.clear()
            m_hum.clear()
            m_press.clear()
            m_lum.clear()
            last_send = time.time()

        time.sleep(10)

if __name__ == "__main__":
    main()
