#!/bin/sh
set -x

BASE_PATH=~/podcasts
STREAMRIPPER=`which cvlc`
PODCAST_DIR=
OUTPATH=
RECORD=1
HOST=
NAME=
DURATION=
URL=
PODCAST_HOST=
PODCAST_DESCRIPTION=

loadConfig () {
  CONFIG_FILE="$1"
  [ -f "${CONFIG_FILE}" ] || fail "Could not find config file \"$CONFIG_FILE\""
  . "$1"
}

readArguments() {
  while getopts :b:c:d:gh:s: opt; do
    case $opt in
      b) BASE_PATH="$OPTARG";;
      c) loadConfig "$OPTARG";;
      d) PODCAST_DIR="$OPTARG";;
      g) RECORD=0;;
      h) HOST="$OPTARG";;
      s) STREAMRIPPER="$OPTARG";;
      ?) echo "Invalid option \"$OPTARG\"" >&2 && exit 1
    esac
  done

  shift $((OPTIND - 1))
  NAME=$1
  DURATION=$2
  URL=$3
  [ -z $PODCAST_DIR ] && PODCAST_DIR="$BASE_PATH/$NAME"
  OUTPATH=$PODCAST_DIR/`date +%Y-%m-%d`.mp3
}

record() {
  if [ $RECORD != "1" ]; then
    return
  fi
  mkdir -p "$PODCAST_DIR" || fail "Cannot create output directory"
  # append a UUID URL parameter to skip ads
  UUID=$(uuidgen)
  # example: cvlc -vvv 'http://playerservices.streamtheworld.com/api/livestream-redirect/WRURFM.mp3?uuid=ba818f8d-0f4b-4775-bbec-00ec32fa5bc4' --sout=file/mp3:/storage/files/podcasts/test.mp3 --run-time=60 vlc://quit
  $STREAMRIPPER "${URL}?uuid=${UUID}" --sout="file://${OUTPATH}" --run-time="${DURATION}" vlc://quit
}

generateXML() {
  header='<?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
  <title>%s</title>
  <description>%s</description>
  <itunes:title>%s</itunes:title>
  <itunes:description>%s</itunes:description>
  <link>%s</link>
  %s
  <itunes:author>Blergh</itunes:author>'
  footer='</channel>
  </rss> '

  item='<item>
  <title>%s - %s</title>
  <description></description>
  <pubDate>%s</pubDate>
  <guid>%s</guid>
  <itunes:duration>%s</itunes:duration>
  <enclosure url="%s" type="audio/mpeg"/>
  %s
  </item>'
  image=''
  if [ -f "$PODCAST_DIR.png" ]
  then
    image="<itunes:image href=\"$HOST/$NAME.png\" />"
  fi
  if [ -f "$PODCAST_DIR.jpg" ]
  then
    image="<itunes:image href=\"$HOST/$NAME.jpg\" />"
  fi
  printf "$header" "$NAME" "$PODCAST_DESCRIPTION" "$NAME" "$PODCAST_DESCRIPTION" "$HOST/$NAME" "$image" > $BASE_PATH/$NAME.xml
  listEpisodes | extractDate | while read episodeDate
  do
    humanDate=`date -d "$episodeDate" +%Y-%m-%d`
    pubDate=`date -d "$episodeDate" +"%a, %d %b %Y %T %z"`
    guid="$HOST/$NAME/$episodeDate"
    url="$HOST/$NAME/$episodeDate.mp3"
    printf "$item" "$NAME" "$humanDate" "$pubDate" "$guid" "$DURATION" "$url" "$image" >> $BASE_PATH/$NAME.xml
  done
  printf "$footer\n" >> "$BASE_PATH/$NAME.xml"
}

listEpisodes() {
  find "$PODCAST_DIR" -name "*.mp3" | sort -r
}

extractDate() {
  sed -e "s/.*\/\(.*\)\.mp3/\\1/g"
}

validateSettings() {
  [ -x "$STREAMRIPPER" ] || fail "Could not find executable streamripper at '$STREAMRIPPER'"
  [ "" = "$NAME" ] && usage
  [ "" = "$URL" ] && usage
  [ "" = "$DURATION" ] && usage
}

usage() {
  echo "Usage:\n"
  echo "blergh  [  ‐b base_path ] [ ‐c config ] [ ‐d podcasts_dir ] [ ‐g ] [ ‐h
       host ] [ ‐s streamripper ] name duration url"
  exit 1
}

blergh() {
  readArguments "$@"
  validateSettings
  record
  generateXML
}

fail() {
  echo $1 >&2 && exit 1
}

blergh "$@"
