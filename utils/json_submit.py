#!/usr/bin/env python3

import json
import sys
import subprocess
import re
import os
import argparse

def check_exe(config):
    exe_list = [key for key in config.keys() if not key.startswith('-')]
    if len(exe_list) != 1:
        print(f"Found {len(exe_list)} executables instead of 1: {exe_list}")
        sys.exit(0)
    return exe_list[0]

def parse_env(string):
    parsed = string[:]
    regex = r"\$\{([_a-zA-Z][_a-zA-Z0-9]*)\}"
    env_vars = set(re.findall(regex, parsed))
    for v in env_vars:
        val = os.environ.get(v)
        if val is None:
            print(f"No value found in env for $\u007b{v}\u007d! Aborting!")
            sys.exit(1)
        print(f"Replacing $\u007b{v}\u007d with {val}")
        parsed = parsed.replace(f"$\u007b{v}\u007d", val)
    return parsed

def get_cmd_elt(key, val, escape_val):
    if isinstance(val, list):
        values = val
    else:
        values = [val]

    cmd = ""

    for v in values:
        v = parse_env(v)
        if escape_val:
            cmd = f"{cmd} {key} \"{v}\""
        else:
            cmd = f"{cmd} {key} {v}"

    return cmd

def get_sub_cmd(config, escape_val=True):
    cmd = "jobsub_submit"

    exe_key = check_exe(config)

    for key, val in config.items():
        if key != exe_key:
            cmd = f"{cmd} {get_cmd_elt(key, val, escape_val)}"

    cmd = f"{cmd} {parse_env(exe_key)} {' '.join(config[exe_key])}"

    return cmd

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Parse json config to send a batch job.")
    parser.add_argument('filename')
    parser.add_argument('--dry-run', dest='dry_run', default=False, action="store_true", help="Parse the file without actually sending the jobs.")
    args = parser.parse_args()

    json_file = args.filename

    with open(json_file) as f:
        config = json.load(f)

    dir_path = os.path.dirname(os.path.realpath(json_file))
    os.environ['CWD'] = dir_path

    cmd = get_sub_cmd(config, escape_val=True)

    print("Parsed command:")
    print(cmd)

    if not args.dry_run:
        print("Calling jobsub with this command")
        rc = subprocess.call(cmd, shell=True)
        exit(rc)
