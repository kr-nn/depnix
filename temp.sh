while getopts "ab:" flag; do
  echo "flag=$flag, arg=$OPTARG, optind=$OPTIND"
done
