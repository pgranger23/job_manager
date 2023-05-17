#!/bin/python3

import argparse
from glob import glob
import os
import re
import sys
from dataclasses import dataclass, field
import yaml
from typing import Dict, Set, List
import json
from json_submit import get_sub_cmd, check_exe
import subprocess
from tempfile import NamedTemporaryFile
import numpy as np

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

colormap = {
    0: bcolors.OKGREEN,
    1: bcolors.WARNING,
    2: bcolors.OKBLUE
}

@dataclass
class Step:
    name: str
    odir: str
    script: str
    files: Set[int] = field(default_factory=set)
    temp: Set[int] = field(default_factory=set)
    to_process: List[int] = field(default_factory=list)

class Process:
    def __init__(self, path_file:str, dry=False):
        self.dry = dry
        self._parse_path(path_file)
        self._check_path()
        self._build_filelists()
        self._clear_temp()
        self._compute_process()

    def _check_path(self) -> None:
        for step in self.path:
            if not os.path.exists(step.odir):
                print(f"{step.odir} does not exist!")
                sys.exit(1)
            if not os.path.exists(step.script):
                print(f"{step.script} does not exist!")
                sys.exit(1)

    def _parse_path(self, fname: str) -> None:
        with open(fname) as f:
            data = yaml.load(f, Loader=yaml.loader.SafeLoader)
        path = []
        for s in data['path']:
            step = Step(**s)
            path.append(step)

        N = data['Nfiles']

        self.path = path
        self.N = N

    def _build_filelists(self) -> None:
        for step in self.path:
            files = glob(f"{step.odir}/*.root")
            files = map(os.path.basename, files)
            numbers_files = [int(re.search(r"_(\d+).root", f).group(1)) for f in files]
            numbers_files = [nb for nb in numbers_files if nb < self.N]
            step.files = set(numbers_files)

            temp = glob(f"{step.odir}/*.temp")
            temp = map(os.path.basename, temp)
            numbers_temp = [int(re.search(r"(\d+)", f).group(1)) for f in temp]
            numbers_temp = [nb for nb in numbers_temp if nb < self.N]
            step.temp = set(numbers_temp)

    def _compute_process(self) -> None:
        mat = np.ones((self.N, len(self.path)), dtype=np.int)
        for j, step in enumerate(self.path):
            for i in step.files:
                mat[i, j] = 0
            for i in step.temp:
                mat[i, j] = 2
        self.state = mat

        for i in range(self.N):
            next_step = self._get_next_step(i)
            if next_step is not None:
                next_step.to_process.append(i)

    def _send_jobs(self, step:Step) -> None:
        map_file = self._create_map(step)

        json_file = step.script
        with open(json_file) as f:
            config = json.load(f)

        dir_path = os.path.dirname(os.path.realpath(json_file))
        os.environ['CWD'] = dir_path

        map_file_url = f"dropbox://{map_file}"

        val = [map_file_url]

        if "-f" in config:
            val = config['-f']
            if isinstance(val, list):
                val.append(map_file_url)
            else:
                val = [val, map_file_url]

        config["-f"] = val
        config["-N"] = str(len(step.to_process))

        exe_key = check_exe(config)
        config[exe_key].append(os.path.basename(map_file))

        jobid = self._submit_job(config)
        jid, server = jobid.split('@')
        clusterid = jid.split('.')[0]

        if not self.dry:
            for i, jid in enumerate(step.to_process):
                cur_jobid = f"{clusterid}.{i}@{server}"
                self._create_temp(step, jid, cur_jobid)

    def _submit_job(self, config:Dict) -> int:
        cmd = get_sub_cmd(config, escape_val=True)
        print(f"Command to execute: {cmd}")

        jobid = "999999.0@test.fnal.gov"
        if not self.dry:
            print("Calling jobsub with this command")
            ret = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
            print(ret.stdout)
            ret.check_returncode()
            jobid = self._extract_jobid(ret.stdout)
        return jobid


    def submit(self) -> None:
        for step in self.path:
            if step.to_process:
                print(f"Going to submit {len(step.to_process)} jobs for step {step.name}")
                self._send_jobs(step)


    def _get_next_step(self, i) -> Step:
        if np.sum(self.state[i]) == 0: #All ok
            return None
        if 2 in self.state[i]: #Temp file there, a job is in progress
            return None
        return self.path[np.argmax(self.state[i] == 1)]

    def display(self, skip_ok:bool = False) -> None:
        for i in range(self.N):
            if skip_ok and self._get_next_step(i) is None:
                continue
            line = f"[{i}] =>"
            for j, step in enumerate(self.path):
                color = colormap[self.state[i, j]]
                line += f" {color}{step.name}{bcolors.ENDC}"
            print(line)

    def print_process(self) -> None:
        for step in self.path:
            print(f"{step.name} => {step.to_process}")
            

    def _clear_temp(self, full:bool = False) -> None:
        for step in self.path:
            if full:
                new_files = step.temp
            else:
                new_files = step.temp.intersection(step.files)
            if new_files:
                for i in new_files:
                    fname = f"{step.odir}/{i}.temp"
                    if not self.dry:
                        os.remove(fname)
                    # else:
                    #     print(f"Would remove {fname}")
                
                step.temp = step.temp - new_files
                print(f"Cleaned {len(new_files)} temp files for step {step.name}")

    def _create_temp(self, step:Step, i:int, jobid:str) -> None:
        if not self.dry:
            fname = f"{step.odir}/{i}.temp"
            with open(fname, 'a') as f:
                f.write(jobid)

    def _create_map(self, step) -> str:
        with NamedTemporaryFile(mode='w', delete=False, suffix='.tmp', prefix='map') as handle:
            handle.write('\n'.join(map(str, step.to_process)))
            fname = handle.name
        return fname

    def reset_temp(self) -> None:
        self._clear_temp(full=True)

    def _extract_jobid(self, stdout) -> str:
        expr = r'\d+\.\d+@.*\.fnal\.gov'
        return re.search(expr, stdout).group(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Restarts failed jobs")
    parser.add_argument('path_file')
    parser.add_argument('action', choices=['send', 'clear', 'dry'])
    args = parser.parse_args()

    path_file = args.path_file

    p = Process(path_file, args.action == 'dry')
    # p.reset_temp()
    p.display(skip_ok=False)
    p.print_process()

    if args.action == 'send':
        p.submit()
    elif args.action == 'clear':
        p.reset_temp()

    # summary = []

    # to_process = {}

    # for missing, step in reversed(list(zip(summary, path))):
    #     for run in missing:
    #         if run in to_process:
    #             to_process[run].insert(0, step)
    #         else:
    #             to_process[run] = [step]

    # if not args.dry_run:
    #     bdag = BuildDag(to_process)
    #     bdag.process()
    

# class BuildDag:
    
#     def __init__(self, to_process:Dict[int, Step]):
#         self.to_process = to_process
#         self.dag = None
#         self.dag_file = None

#     def process(self):
#         self.build_dag()
#         self.create_dag()
#         print(self.dag_file)
#         self.submit_dag()

#     def get_run_cmd(self, run: int, step: str, escape_val: bool = False) -> str:
#         json_file = step.script
#         with open(json_file) as f:
#             config = json.load(f)

#         config["-N"] = 1

#         cmd = get_sub_cmd(config, escape_val)
#         cmd = f"{cmd} {run}"
#         return cmd

#     def build_serial(self, run: int, path: str) -> str:
#         script = "<serial>\n"

#         for step in path:
#             cmd = self.get_run_cmd(run, step, escape_val=False)
#             script += f"{cmd}\n"

#         script += "</serial>"

#         return script

#     def build_dag(self):
#         self.dag = "<parallel>\n"

#         for run, path in self.to_process.items():
#             print(f"{run} -> {[s.name for s in path]}")
#             if len(path) == 1:
#                 step = path[0]
#                 cmd = self.get_run_cmd(run, step, False)
#             else:
#                 cmd = self.build_serial(run, path)
#             self.dag += f"{cmd}\n"


#         self.dag += "</parallel>"

#     def submit_dag(self) -> None:
#         assert(self.dag_file is not None)
#         cmd = f"jobsub_submit -G dune --dag file://{self.dag_file}"
#         subprocess.run(cmd, shell=True)

#     def create_dag(self) -> None:
#         assert(self.dag is not None)
#         self.dag_file = mktemp()
#         with open(self.dag_file, 'w') as f:
#             f.writelines(self.dag)