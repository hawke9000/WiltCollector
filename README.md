# WiltCollector

[![Build Status](https://travis-ci.org/oliveroneill/WiltCollector.svg?branch=master)](https://travis-ci.org/oliveroneill/WiltCollector)
[![Platform](https://img.shields.io/badge/Swift-4.1-orange.svg)](https://img.shields.io/badge/Swift-4.1-orange.svg)
[![Swift Package Manager](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)


A program for periodically updating Wilt user's play histories.

This is intended to run on AWS Lambda using CloudWatch to trigger updates.

## Running tests
```bash
swift test
```

## Deploying
To build a packaged zip that contains the built program, run:
```bash
./deploy.sh
```
This will create a zip called `WiltCollector.zip` in `deploy/`.
This can then be uploaded to S3 and connected to Lambda. `index.js` is the
Lambda handler and currently logs all output from the Swift program and the
handler returns an empty string on completion.

You'll need to copy your credentials file at `$GOOGLE_APPLICATION_CREDENTIALS`
to `deploy/credentials.json`.


## AWS Setup
### Lambda
You'll need to set environment variables `BIGQUERY_PROJECT_ID`,
`SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` in the Lambda console.
**NOTE**: `BIGQUERY_PROJECT_ID` is now also used for the Firebase project ID,
so you'll need to ensure these exist under the same project within Google
Cloud. These should be separated into separate environment variables at some
point soon.

### BigQuery
You'll need to create a BigQuery table called `wilt_play_history.play_history`.

### FireStore
You'll need to create a table called `users`.

### Table Columns
play_history (BigQuery): user_id, date, artists, name, primary_artist, track_id

users (FireStore): access_token, expires_at, refresh_token

## TODO
- Some sort of exponential backoff if requests start failing (in case Spotify bans me)
