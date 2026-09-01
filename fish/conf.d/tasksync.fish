# Sync Taskwarrior to the homelab Garage S3 bucket.
#
# Two things cannot live in ~/.taskrc, hence this wrapper:
#
#   * The credentials and the encryption secret. taskrc expands $VARS, so it
#     refers to $GARAGE_* and $TASK_SYNC_SECRET and keeps no secret itself;
#     they come from ~/.config/garage/taskwarrior-sync.env (mode 0600).
#
#   * The endpoint. Fedora's stock task 3.4.2 has no sync.aws.endpoint_url key
#     (it landed upstream after v3.5.0), so the AWS SDK's own
#     AWS_ENDPOINT_URL_S3 supplies it. That variable is set here for this one
#     command only and never exported: a global value would redirect every
#     other AWS S3 client on this machine at Garage, and ~/.aws holds a live
#     default profile.
#
# See conf:f3s/docs/taskwarrior-s3-sync.md and the f3s-garage skill.
function tasksync --description 'Sync Taskwarrior to the Garage S3 bucket'
    set -l creds "$HOME/.config/garage/taskwarrior-sync.env"

    if not test -r $creds
        echo "tasksync: missing $creds" >&2
        return 1
    end

    # The file is sh syntax (: "${VAR:=default}" plus export), so read the
    # values out of a subshell rather than trying to source it in fish.
    set -l env_kv (sh -c ". $creds; printenv GARAGE_ENDPOINT GARAGE_REGION GARAGE_BUCKET GARAGE_ACCESS_KEY_ID GARAGE_SECRET_ACCESS_KEY TASK_SYNC_SECRET")

    if test (count $env_kv) -lt 6
        echo "tasksync: could not read all values from $creds" >&2
        return 1
    end

    env GARAGE_ENDPOINT=$env_kv[1] \
        GARAGE_REGION=$env_kv[2] \
        GARAGE_BUCKET=$env_kv[3] \
        GARAGE_ACCESS_KEY_ID=$env_kv[4] \
        GARAGE_SECRET_ACCESS_KEY=$env_kv[5] \
        TASK_SYNC_SECRET=$env_kv[6] \
        AWS_ENDPOINT_URL_S3=$env_kv[1] \
        task sync $argv
end
