#!/usr/bin/env python3
import argparse, json, sys, os

conf = argparse.ArgumentParser()
conf.add_argument("-c", "--conf", required=True,
	help="path to the JSON configuration file")
args = vars(conf.parse_args())
f = open(args["conf"], encoding='utf-8')
decode_config = json.load(f)
encode_config = json.dumps(decode_config)
print(encode_config)
