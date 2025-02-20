#!/bin/bash

# Configurações do servidor
HOST="localhost"
PORT=25565
MINECRAFT_DIR="/home/minecraft"
OUTPUT_DIR="./resultados"
INSTANCE_IP="52.200.160.8"          # Endereço IP da instância
SSH_KEY_PATH="./labsuser.pem"        # Caminho para a chave PEM
USER="ubuntu"                        # Usuário da instância (ex: 'ubuntu', 'ec2-user', etc.)
INSTANCE_TYPE="e2-large"
DURATION=120                         # Duração do teste em segundos

# Cenários para os testes
SCENARIOS=(
  "2 5"
  "2 10"
  "2 15"
  "4 5"
  "4 10"
  "4 15"
)

# Criar diretório de saída local
mkdir -p "$OUTPUT_DIR"

echo "========== INICIANDO O SCRIPT =========="
echo "Conectando à instância e iniciando o servidor..."

for scenario in "${SCENARIOS[@]}"; do
  # Extrair os parâmetros do cenário
  RAM_SIZE=$(echo "$scenario" | awk '{print $1}')
  RENDER_DISTANCE=$(echo "$scenario" | awk '{print $2}')

  # Nome do arquivo de saída
  OUTPUT_FILE="$OUTPUT_DIR/test_results_${RAM_SIZE}GB_${RENDER_DISTANCE}chunks.json"

  echo "========== INICIANDO O TESTE COM OS PARÂMETROS =========="
  echo "RAM: ${RAM_SIZE}GB, Distância de Renderização: ${RENDER_DISTANCE} chunks"
  echo "Arquivo de saída: $OUTPUT_FILE"

  ssh -i "$SSH_KEY_PATH" "$USER@$INSTANCE_IP" << EOF
    echo "Conectado à instância!"
    cd "$MINECRAFT_DIR" || { echo "ERRO: Diretório $MINECRAFT_DIR não encontrado"; exit 1; }

    # Ajusta a distância de renderização no arquivo server.properties
    sed -i "s/^view-distance=.*/view-distance=${RENDER_DISTANCE}/" "$MINECRAFT_DIR/server.properties"

    echo "Iniciando o servidor Minecraft..."
    screen -dmS mcs java -Xmx${RAM_SIZE}G -Xms${RAM_SIZE}G -jar paper-1.21.4-164.jar nogui
    sleep 60  # Aguardar 60 segundos para o servidor iniciar
    echo "Servidor iniciado."

    # Verifica se o arquivo de log existe
    if [ ! -f "$MINECRAFT_DIR/logs/latest.log" ]; then
      echo "ERRO: Arquivo de log latest.log não encontrado!"
      exit 1
    fi

    # Cria o diretório de resultados e ajusta as permissões
    mkdir -p "$MINECRAFT_DIR/results"
    chmod -R 777 "$MINECRAFT_DIR/results"

    echo "Iniciando o teste de desempenho..."
    start_time=\$(date +%s)
    end_time=\$(( start_time + ${DURATION} ))

    # Cria o arquivo de resultados e ajusta suas permissões
    touch "$MINECRAFT_DIR/results/test_results.json"
    chmod 666 "$MINECRAFT_DIR/results/test_results.json"

    echo "Arquivo de saída criado: $MINECRAFT_DIR/results/test_results.json"
    echo "Coletando métricas a cada 30 segundos..."

    collect_metrics() {
      echo "Coletando métricas..."

      # Extração do TPS:
      # Exemplo: [14:15:13] [Server thread/INFO]: TPS from last 1m, 5m, 15m: 20.0, 20.0, 20.0
	tps=$(grep -Po 'TPS from last 1m, 5m, 15m: \K[0-9.]+' "$MINECRAFT_DIR/logs/latest.log" | tail -n 1)

      # Extração do MSPT:
      # Exemplo:
      # [14:15:27] [Server thread/INFO]: Server tick times (avg/min/max) from last 5s, 10s, 1m:
      # [14:15:27] [Server thread/INFO]: ◴ 0.4/0.3/0.7, 0.4/0.3/1.4, 0.3/0.3/48.1
      mspt=$(grep -A 1 -i "Server tick times (avg/min/max)" "$MINECRAFT_DIR/logs/latest.log" \
       | grep -Po '^\s*[^0-9]*\K[0-9.]+' | tail -n 1)


      # Extração do CPU usando ps aux:
      cpu_usage=\$(ps aux | grep -i "[j]ava" | awk '{sum+=\$3} END {if (sum==0) print "N/A"; else printf "%.1f", sum}')

      ram_usage=\$(free -m | grep Mem | awk '{print \$3}')
      disk_usage=\$(df -h / | grep ' /' | awk '{print \$5}')
      latency=\$(ping -c 1 $HOST | grep 'time=' | sed 's/.*time=\([0-9.]*\) ms/\1/')

      [ -z "\$tps" ] && tps="N/A"
      [ -z "\$mspt" ] && mspt="N/A"
      [ -z "\$cpu_usage" ] && cpu_usage="N/A"
      [ -z "\$ram_usage" ] && ram_usage="N/A"
      [ -z "\$disk_usage" ] && disk_usage="N/A"
      [ -z "\$latency" ] && latency="N/A"


      echo "{ \"tps\": \"\$tps\", \"mspt\": \"\$mspt\", \"cpu_usage\": \"\$cpu_usage\", \"ram_usage\": \"\$ram_usage\", \"disk_usage\": \"\$disk_usage\", \"latency\": \"\$latency\" }" >> "$MINECRAFT_DIR/results/test_results.json"
      echo "Métricas salvas: $MINECRAFT_DIR/results/test_results.json"
    }

    while [ \$(date +%s) -lt \$end_time ]; do
      collect_metrics
      sleep 30
    done

    screen -S mcs -X quit
    echo "Teste concluído. Resultados em $MINECRAFT_DIR/results/test_results.json"
EOF

  echo "Transferindo os resultados para a máquina local..."
  scp -i "$SSH_KEY_PATH" "$USER@$INSTANCE_IP:$MINECRAFT_DIR/results/test_results.json" "$OUTPUT_FILE"
  exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    echo "Transferência concluída. Resultados salvos em $OUTPUT_FILE"
    echo "Removendo arquivo de métricas do servidor..."
    ssh -i "$SSH_KEY_PATH" "$USER@$INSTANCE_IP" "rm -f $MINECRAFT_DIR/results/test_results.json"
    if [ $? -eq 0 ]; then
      echo "Arquivo de métricas removido do servidor com sucesso."
    else
      echo "Falha ao remover o arquivo de métricas do servidor."
    fi
  else
    echo "ERRO: Falha na transferência do arquivo."
  fi
done
