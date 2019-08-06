CHECK_INTERVAL_S=1
INIT_PATH=/vault/init

vault server -config=/vault/config/local.json 2>&1 &

if [ -z $VAULT_ADDR ]; then
  export VAULT_ADDR=http://127.0.0.1:8200
fi

while $true; do
  VAULT_STATUS=$(curl --write-out "%{http_code}\n" --silent --output /dev/null $VAULT_ADDR/v1/sys/health)
  case $VAULT_STATUS in
    200)
      echo "Vault is initialized, unsealed and active."
      export CHECK_INTERVAL_S=60
      ;;
    429|473)
      echo "Vault is initialized, unsealed and in standby mode."
      export CHECK_INTERVAL_S=60
      ;;
    501)
      echo "Vault is not initialized."
      echo "Initializing..."
      RANDOM_TEMP_FILE=/tmp/$RANDOM.txt
      vault operator init -recovery-shares=1 -recovery-threshold=1 -key-shares=1 -key-threshold=1 > $RANDOM_TEMP_FILE
      export VAULT_RECOVERY_KEY=$(cat $RANDOM_TEMP_FILE | grep "Recovery Key 1" | sed 's/Recovery Key 1: //')
      export VAULT_TOKEN=$(cat $RANDOM_TEMP_FILE | grep "Initial Root Token" | sed 's/Initial Root Token: //')
      mkdir -p $INIT_PATH
      echo $VAULT_RECOVERY_KEY > $INIT_PATH/key.txt
      echo $VAULT_TOKEN > $INIT_PATH/token.txt
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "! WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING !"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo 
      echo "The recovery key and root token are displayed below in case you want to recovery the Vault or re-authenticate."
      echo
      echo "Recovery key: $VAULT_RECOVERY_KEY"
      echo "Initial Root Token: $VAULT_TOKEN"
      echo
      echo "This Vault instance is not yet secure and the initial root token and recovery key are only meant for automatic"
      echo "initialization of this cluster."
      echo
      echo "Make sure to revoke the root token and rekey this Vault instance!"
      echo
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "! WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING !"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      rm -f $RANDOM_TEMP_FILE

      if [ ! -f $HOME/initialized.txt ]; then
        # Create token to allow prometheus access to metrics
        until vault login $(cat $INIT_PATH/token.txt)
        do
          echo "Wait until Vault is available to proceed with configuration tasks."
          sleep 1
        done
        vault policy write prometheus -<<EOF
path "sys/metrics" {
  capabilities = ["read"]
}
EOF
        vault token create -id prometheus-token -policy=default -policy=prometheus
        touch $HOME/initialized.txt
      fi

      ;;
    *)
      echo "Vault is in an unkown state. Status code $VAULT_STATUS"
      ;;
  esac
  echo "Next check in $CHECK_INTERVAL_S seconds."
  sleep $CHECK_INTERVAL_S
done