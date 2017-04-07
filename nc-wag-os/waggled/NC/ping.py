#!/usr/bin/env python3
'''
A python script that creates and sends a ping.
'''
import sys
from waggle.protocol.utils import packetmaker
sys.path.append('../DataCache/')
from send2dc import send


packet = packetmaker.make_ping_packet()
print('Ping packet made...')
for pack in packet:
    send(pack)
print('Ping packet sent.')
