#!/bin/bash


openssl genrsa -out temp/ca.key 2048
openssl req -x509 -new -nodes -key temp/ca.key -subj "/CN=ca.kuberise.com" -days 10000 -out temp/ca.crt
