@echo off
rem Abre o n8n do Radar de Noticias ao ligar o computador.
rem O IPv4 vem primeiro porque, nesta rede, a conexao IPv6 com o Telegram falha de vez em quando.
set "NODE_OPTIONS=--dns-result-order=ipv4first"
start "n8n - Radar de Noticias" /min cmd /k npx n8n
