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
      ;;
    501)
      echo "Vault is not initialized."
      echo "Initializing..."
      RANDOM_TEMP_FILE=/tmp/$RANDOM.txt
      vault operator init -recovery-shares=1 -recovery-threshold=1 -key-shares=1 -key-threshold=1 > $RANDOM_TEMP_FILE
      export VAULT_UNSEAL_KEY=$(cat $RANDOM_TEMP_FILE | grep "Unseal Key 1" | sed 's/Unseal Key 1: //')
      export VAULT_TOKEN=$(cat $RANDOM_TEMP_FILE | grep "Initial Root Token" | sed 's/Initial Root Token: //')
      mkdir -p $INIT_PATH
      echo $VAULT_UNSEAL_KEY > $INIT_PATH/key.txt
      echo $VAULT_TOKEN > $INIT_PATH/token.txt
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "! WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING !"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo 
      echo "The unseal key and root token are displayed below in case you want to seal/unseal the Vault or re-authenticate."
      echo
      echo "Unseal key: $VAULT_UNSEAL_KEY"
      echo "Initial Root Token: $VAULT_TOKEN"
      echo
      echo "This Vault instance is not yet secure and the initial root token and unseal key are only meant for automatic"
      echo "initialization of this cluster."
      echo
      echo "Make sure to revoke the root token and rekey this Vault instance!"
      echo
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "! WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING - INSECURE - WARNING !"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      rm -f $RANDOM_TEMP_FILE
      ;;
    503)
      echo "Vault is initialized and sealed."
      echo "Unsealing..."
      if [ -z $VAULT_UNSEAL_KEY ]; then
        VAULT_UNSEAL_KEY=$(cat $INIT_PATH/key.txt)
      fi
      vault operator unseal $VAULT_UNSEAL_KEY

      if [ ! -f $HOME/initialized.txt ]; then
        touch $HOME/initialized.txt
        ### Make sure transit engine, key and token is created for auto-unseal
        vault login $(cat $INIT_PATH/token.txt)
        vault secrets enable transit
        vault write -f transit/keys/auto-unseal
        vault policy write auto-unseal -<<EOF
path "transit/encrypt/auto-unseal" {
  capabilities = ["update"]
}

path "transit/decrypt/auto-unseal" {
  capabilities = ["update"]
}
EOF
        vault token create -id auto-unseal-token -policy=auto-unseal
      fi
      ;;
    *)
      echo "Vault is in an unkown state. Status code $VAULT_STATUS"
      ;;
  esac
  echo "Next check in $CHECK_INTERVAL_S seconds."
  sleep $CHECK_INTERVAL_S
done