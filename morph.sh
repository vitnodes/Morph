#!/bin/bash

# Логотип
echo -e '\e[32m'
echo -e '██    ██ ██████  ██   ██ ██    ██ ██████  '
echo -e '██    ██ ██   ██ ██   ██ ██    ██ ██   ██ '
echo -e '██    ██ ██   ██ ███████ ██    ██ ██████  '
echo -e ' ██  ██  ██   ██ ██   ██ ██    ██ ██   ██ '
echo -e '  ████   ██████  ██   ██  ██████  ██████  '
echo -e '\e[0m'

echo -e " Підписуйтесь на наш офіційний канал VDHUB, щоб бути в курсі найактуальніших новин та аналітики у світі криптовалют - https://t.me/vdhub_crypto"

sleep 2

while true; do
  # Меню
  PS3='Оберіть опцію: '
  options=("Встановити ноду Morph" "Видалити ноду Morph" "Перевірити працездатність ноди" "Додати моніторинг через Telegram-бота" "Вийти зі скрипта")
  select opt in "${options[@]}"
  do
      case $opt in
          "Встановити ноду Morph")
              echo "Починаємо встановлення ноди Morph..."

              # Оновлення системи та встановлення необхідних пакетів
              echo "Оновлення системи та встановлення необхідних пакетів..."
              sudo apt update && sudo apt upgrade -y
              sudo apt install curl git jq lz4 build-essential unzip make lz4 gcc jq ncdu tmux cmake clang pkg-config libssl-dev python3-pip protobuf-compiler bc -y

              # Встановлення Go
              echo "Встановлення Go..."
              sudo rm -rf /usr/local/go
              curl -Ls https://go.dev/dl/go1.22.2.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
              eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
              eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
              go version

              # Встановлення Docker та Docker Compose
              echo "Встановлення Docker та Docker Compose..."
              sudo apt install -y ca-certificates curl gnupg lsb-release
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io
              sudo usermod -aG docker $USER
              newgrp docker
              sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose

              # Встановлення Geth
              echo "Встановлення Geth..."
              mkdir -p ~/.morph
              cd ~/.morph
              git clone https://github.com/morph-l2/morph.git
              cd morph
              git checkout v0.1.0-beta
              make nccc_geth
              cd ~/.morph/morph/node
              make build

              # Завантаження та розпаковка даних
              echo "Завантаження та розпаковка даних..."
              cd ~/.morph
              wget https://raw.githubusercontent.com/morph-l2/config-template/main/holesky/data.zip
              unzip data.zip

              # Створення Secret Key
              echo "Створення Secret Key..."
              cd ~/.morph
              openssl rand -hex 32 > jwt-secret.txt
              echo "Пауза 30 сек... Збережіть Secret Key у надійному місці та не загубіть..."
              cat jwt-secret.txt
              sleep 30

              # Запуск ноди Geth
              echo "Запуск ноди Geth..."
              screen -S geth -d -m ~/.morph/morph/go-ethereum/build/bin/geth --morph-holesky \
                  --datadir "./geth-data" \
                  --http --http.api=web3,debug,eth,txpool,net,engine \
                  --http.port 8546 \
                  --authrpc.addr localhost \
                  --authrpc.vhosts="localhost" \
                  --authrpc.port 8551 \
                  --authrpc.jwtsecret=./jwt-secret.txt \
                  --miner.gasprice="100000000" \
                  --log.filename=./geth.log \
                  --port 30363

              # Запуск ноди Morph
              echo "Запуск ноди Morph..."
              screen -S morph -d -m ~/.morph/morph/node/build/bin/morphnode --home ./node-data \
                  --l2.jwt-secret ./jwt-secret.txt \
                  --l2.eth http://localhost:8546 \
                  --l2.engine http://localhost:8551 \
                  --log.filename ./node.log

              echo "Встановлення завершено!"
              break
              ;;
              
          "Видалити ноду Morph)
              echo "Видалення ноди Morph..."
              sudo rm -rf ~/.morph
              sudo docker system prune -a -f
              screen -S geth -X quit
              screen -S morph -X quit
              screen -S telegram_bot -X quit
              echo "Ноду Morph успішно видалено"
              break
              ;;
              
          "Перевірити працездатність ноди")
              echo "Перевірка працездатності ноди..."
              curl -X POST -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":74}' http://localhost:8546
              curl http://localhost:26657/status
              break
              ;;
              
          "Додати моніторинг через Telegram-бота")
              read -p "Введіть API-ключ від Telegram-бота: " API_KEY
              read -p "Введіть ваш User ID у Telegram: " USER_ID
              read -p "Введіть інтервал перевірки (в секундах, за замовчуванням 600): " CHECK_INTERVAL
              CHECK_INTERVAL=${CHECK_INTERVAL:-600}  # Значення за замовчуванням – 600 секунд
              
              echo "Встановлюємо залежності Python..."
              sudo apt install python3 -y
              sudo apt install pip -y
              apt install python3-python-telegram-bot
              apt install python3-requests
              echo "Створюємо і запускаємо скрипт моніторингу..."
              cat <<EOF > ~/.morph/node_monitor.py
import requests
import time
import json
from telegram import Bot

api_key = $API_KEY
user_id = $USER_ID
check_interval = $CHECK_INTERVAL

bot = Bot(token=api_key)

# Функція для перевірки стану ноди
def check_node_status():
    try:
        response_geth = requests.post('http://localhost:8546', json={"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":74})
        response_morph = requests.get('http://localhost:26657/status')

        if response_geth.status_code == 200 and response_morph.status_code == 200:
            geth_data = response_geth.json()
            morph_data = response_morph.json()
            
            message = f"🟢 Нода Morph працює коректно!\n\n" \
                      f"🔗 Geth Peer Count: {geth_data['result']}\n" \
                      f"📝 Morph Node Status: {json.dumps(morph_data, indent=2)}"
            bot.send_message(chat_id=user_id, text=message)
        else:
            bot.send_message(chat_id=user_id, text="🔴 Проблеми з нодою Morph!")
    except Exception as e:
        bot.send_message(chat_id=user_id, text=f"⚠️ Помилка при перевірці ноди: {e}")

# Основний цикл моніторингу
if __name__ == "__main__":
    notifications_enabled = True
    
    while True:
        if notifications_enabled:
            check_node_status()
        
        time.sleep(check_interval)
EOF
              chmod +x ~/.morph/node_monitor.py
              echo "Запуск скрипта мониторинга..."
              screen -S telegram_bot -d -m python3 ~/.morph/node_monitor.py
              echo "Моніторинг ноди через Telegram-бота встановлено"
              break
              ;;
              
          "Вийти зі скрипта")
              echo "Вихід..."
              exit 0
              ;;
              
          *) echo "Невірний вибір, спробуйте знову.";;
      esac
  done
done
