#!/bin/bash

AWS_HOME=~/.aws
AWS_CREDENTIALS_FILE=$AWS_HOME/credentials
BACKUP_CREDENTIALS_FILE=$AWS_HOME/credentials-"$(date +%Y%m%d%H%M%S)"

usage() {
    local text
    text="Usage: $0 "
    text+="[-s | --source-profile <AWS profile to use for token request>] "
    text+="[-p | --dest-profile <AWS profile to write the temporary credentials to>] "
    text+="[-u | --username <AWS user name>] "
    text+="[-a | --account <AWS account ID>] "
    text+="[-t | --token <Token from MFA device>] "
    text+="[-d | --duration <Token validity time in seconds>] "
    echo "$text" 1>&2
    exit 1
}

clean_up() {
    rm "$TEMP_FILE"
    echo "Deleted $TEMP_FILE"
}

while :; do
    case $1 in
    -h | --help)
        usage
        ;;
    -s | --source-profile)
        if [ "$2" ]; then
            SOURCE_PROFILE=$2
            shift
        else
            echo "--source-profile requires a non-empty argument"
            exit 1
        fi
        ;;
    -p | --dest-profile)
        if [ "$2" ]; then
            DESTINATION_PROFILE=$2
            shift
        else
            echo "--dest-profile requires a non-empty argument"
            exit 1
        fi
        ;;
    -u | --username)
        if [ "$2" ]; then
            USER_NAME=$2
            shift
        else
            echo "--username requires a non-empty argument"
            exit 1
        fi
        ;;
    -a | --account)
        if [ "$2" ]; then
            ACCOUNTID_ORG=$2
            shift
        else
            echo "--account requires a non-empty argument"
            exit 1
        fi
        ;;
    -t | --token)
        if [ "$2" ]; then
            TOKEN=$2
            shift
        else
            echo "--token requires a non-empty argument"
            exit 1
        fi
        ;;
    -d | --duration)
        if [ "$2" ]; then
            DURATION=$2
            shift
        else
            echo "--duration requires a non-empty argument"
            exit 1
        fi
        ;;
    -?*)
        echo "Unknown option: $1"
        ;;
    *)
        break
        ;;
    esac
    shift
done

if [ -z ${SOURCE_PROFILE+x} ]; then
    echo -n "Please enter name of AWS profile to use for getting temporary credentials: "
    read -r SOURCE_PROFILE
fi

DESTINATION_PROFILE=${DESTINATION_PROFILE-default}
if [ "$SOURCE_PROFILE" == "$DESTINATION_PROFILE" ]; then
    echo "Using the '$DESTINATION_PROFILE' profile (same as source) to update would clobber credentials, aborting."
    exit 1
fi

if [ -z ${USER_NAME+x} ]; then
    echo -n "Please enter AWS username: "
    read -r USER_NAME
fi

if [ -z ${ACCOUNTID_ORG+x} ]; then
    echo -n "Please enter AWS account ID (may include dashes): "
    read -r ACCOUNTID_ORG
fi
ACCOUNTID="${ACCOUNTID_ORG//-/}"

if [ -z ${TOKEN+x} ]; then
    echo -n "Please enter MFA token from your configured device: "
    read -r TOKEN
fi

DURATION=${DURATION-28800}

mkdir -p "$AWS_HOME"
if [ -f "$AWS_CREDENTIALS_FILE" ]; then
    echo "Using credentials from '${AWS_CREDENTIALS_FILE}'."
else
    echo "Credentials file '${AWS_CREDENTIALS_FILE}' not found. Set up credentials before attempting to use MFA."
    exit 2
fi

TEMP_FILE=$(mktemp)
trap clean_up EXIT
echo "Writing response to file $TEMP_FILE"

aws --profile "$SOURCE_PROFILE" sts get-session-token \
    --serial-number arn:aws:iam::"$ACCOUNTID":mfa/"$USER_NAME" \
    --duration-seconds "$DURATION" \
    --token-code "$TOKEN" \
    --output text \
    --query 'Credentials.[AccessKeyId, SecretAccessKey, SessionToken]' \
    > "$TEMP_FILE" ||
    exit 3

# if response contains something else, this might break
read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<< "$(awk '{ print $1, $2, $3 }' < "$TEMP_FILE")"

echo "Creating a backup copy of credentials: '${BACKUP_CREDENTIALS_FILE}'."
cp "$AWS_CREDENTIALS_FILE" "$BACKUP_CREDENTIALS_FILE"

aws --profile "$DESTINATION_PROFILE" configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws --profile "$DESTINATION_PROFILE" configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws --profile "$DESTINATION_PROFILE" configure set aws_session_token "$AWS_SESSION_TOKEN"

echo "Profile '$DESTINATION_PROFILE' updated with temporary credentials."
rm "$BACKUP_CREDENTIALS_FILE"
echo "Deleted ${BACKUP_CREDENTIALS_FILE}"
