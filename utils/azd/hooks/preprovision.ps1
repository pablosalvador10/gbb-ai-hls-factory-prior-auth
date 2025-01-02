$current_user_client_id = (az ad signed-in-user show --query id -o tsv)
azd env set CURRENT_USER_CLIENT_ID $current_user_client_id
