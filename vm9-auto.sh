#!/bin/bash

# Создаем файлы в папке /root
touch /root/auto.sh /root/script1.sh /root/script2.sh /root/script3.sh

# Заполняем auto.sh
cat > /root/auto.sh << 'EOF'
#!/bin/bash


# === Шаг 1: Ввод значений от пользователя ===
read -p "Введите название пула: " POOL
read -s -p "Введите пароль для пользователя bitrix: " BITRIX_PASS
echo

# === Шаг 2: Экспорт переменных среды ===
export POOL
export BITRIX_PASS


# === Шаг 3: Последовательный запуск остальных скриптов ===
/root/script1.sh && /root/script2.sh && /root/script3.sh

# === Шаг 4: Удаление скриптов после выполнения ===
rm -f /root/script1.sh /root/script2.sh /root/script3.sh /root/auto.sh /root/vm9-auto.sh

EOF

# Заполняем script1.sh
cat > /root/script1.sh << 'EOF'
#!/bin/bash

echo "Запуск скрипта..."
dnf clean all
dnf update -y

wget http://repo.bitrix24.tech/dnf/bitrix-env-9.sh -O /root/bitrix-env-9.sh
chmod +x /root/bitrix-env-9.sh

/root/bitrix-env-9.sh
EOF

# Заполняем script2.sh
cat > /root/script2.sh << 'EOF'
#!/usr/bin/expect -f

set timeout 600

set host $env(POOL)

spawn /root/menu.sh

# ===== Создание пула =====
expect "*Enter your choice:*" { send "1\r" }
expect "*Please enter master server name*" { send "$host\r" }
expect "*Please enter any key*" { send "\r" }

# ===== NodeJS Push/RTC =====
expect "*Enter your choice:*" { send "6\r" }
expect "*Enter your choice:*" { send "1\r" }
expect "*Enter hostname or 0 to exit*" { send "$host\r" }

# Обновление NodeJS сервиса
expect {
    -re {create NodeJS Push.*\(Y\|n\)} { send "Y\r" }
}

expect -re "Press ENTER to exit:" { send "\r" }
expect "*Enter hostname or 0 to exit:*" { send "0\r" }
expect "*Enter your choice:*" { send "0\r" }

# ===== Цикл: 70 проверок задач в пункте 10 =====
set count 0
while {$count < 70} {
    expect "*Enter your choice:*"
    send "10\r"

    expect {
        -re {TaskID.*Status.*Last Step} {}
        timeout {
            puts "❌ Не удалось получить список задач"
            exit 1
        }
    }

    expect "*Available actions:*"
    send "0\r"

    incr count
    puts "Цикл задач: $count/70"

    sleep 1
}

# Полный выход из menu.sh
expect "*Enter your choice:*" { send "0\r" }
expect "*Enter your choice:*" { send "0\r" }

# Не ждём EOF, так как menu.sh уже завершён
# Просто делаем паузу для надёжности
sleep 1
EOF

# Заполняем script3.sh
cat > /root/script3.sh << 'EOF'
#!/usr/bin/expect -f

set timeout 300

set host $env(POOL)
set bitrix_pass $env(BITRIX_PASS)

spawn /root/menu.sh

# Пункт 1 — управление серверами
expect "*Enter your choice:*" { send "1\r" }

# Пункт 3 — смена пароля
expect "*Enter your choice:*" { send "3\r" }

expect "Enter server address*" { send "$host\r" }

expect "Enter password for bitrix:" { send "$bitrix_pass\r" }
expect "Re-enter password for bitrix:" { send "$bitrix_pass\r" }

# Подтверждение смены
expect {
    -re "confirm.*bitrix.*\\(y\\|N\\):" { send "y\r" }
    timeout { puts "❌ Не дождались y"; exit 1 }
}

expect -re "Press ENTER to exit:" { send "\r" }
expect "Enter server address*" { send "0\r" }
expect "*Enter your choice:*" { send "0\r" }
expect "*Enter your choice:*" { send "0\r" }
expect eof
EOF

# Делаем все скрипты исполняемыми
chmod +x /root/auto.sh
chmod +x /root/script1.sh
chmod +x /root/script2.sh
chmod +x /root/script3.sh
echo "Скрипты успешно созданы в папке /root"