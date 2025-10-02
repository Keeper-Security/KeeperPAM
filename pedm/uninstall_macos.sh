#!/bin/sh
LAUNCHCTL=/bin/launchctl
DAEMON_PRODUCT_IDENTIFIERS="com.keeper.keeper-privilege-manager com.keeper.keeperse"
AGENT_PRODUCT_IDENTIFIERS="com.keeper.keeper-client"
USER_ID=0
LOG_FILE=/dev/null

WHO_NAME=`/usr/bin/who | /usr/bin/grep console | cut -d' ' -f1`
if [ $? -eq 0 ]; then
    USER_ID=`id -u ${WHO_NAME}`
fi

launchtl_run_cmd()
{
    local subcommand="${1}"
    local identifier="${2}"
    local run_as_user="${3:-root}"
    local process_output=""

    if [ "x${subcommand}" != "xlist" ]; then
        if [ "x${run_as_user}" = "xroot" ]; then
            identifier="/Library/LaunchDaemons/${identifier}.plist"
        else
            identifier="/Library/LaunchAgents/${identifier}.plist"
        fi
    fi

    if [ "x${run_as_user}" = "xroot" ]; then
        echo "Attempting to ${subcommand} ${identifier}" >>"${LOG_FILE}"
        process_output=`$LAUNCHCTL ${subcommand} ${identifier} 2>&1`
    else
        echo "Attempting to ${subcommand} ${identifier} as user ${run_as_user}" >>"${LOG_FILE}"
        process_output=`$LAUNCHCTL asuser ${run_as_user} $LAUNCHCTL ${subcommand} ${identifier} 2>&1`
    fi
    launchctl_exit_code=$?

    echo "$LAUNCHCTL returned '${process_output}' and exit code '${launchctl_exit_code}'" >>"${LOG_FILE}"
}

launchctl_unload_identifier()
{
    local identifer="${1}"
    local run_as_user="${2:-root}"

    echo "" >>"${LOG_FILE}"
    launchtl_run_cmd list "${identifer}" "${run_as_user}"

    # Check to see if it exists before unloading it.
    if [ $launchctl_exit_code -eq 0 ]; then
        launchtl_run_cmd unload "${identifer}" "${run_as_user}"
    fi
}

echo "Unloading daemons and agents."
for product_identifier in $DAEMON_PRODUCT_IDENTIFIERS; do
    launchctl_unload_identifier "${product_identifier}" "root"
done

for product_identifier in $AGENT_PRODUCT_IDENTIFIERS; do
    launchctl_unload_identifier "${product_identifier}" "${USER_ID}"
done

echo "Removing PAM modules"
/Library/Keeper/sbin/Plugins/bin/KeeperPamConfig/KeeperPamConfig --remove=True
/Library/Keeper/sbin/Plugins/bin/KeeperPamConfig/KeeperPamConfig --remove=True --service=authorization

echo "Removing installed files and receipts."
rm -f /Library/LaunchDaemons/com.keeper.keeper-privilege-manager.plist /Library/LaunchDaemons/com.keeper.keeperse.plist /Library/LaunchAgents/com.keeper.keeper-client.plist
rm -rf /Library/Keeper /Applications/Keeper\ Privilege*
rm -f /var/db/receipts/com.keeper.keeper-privilege-manager.*
