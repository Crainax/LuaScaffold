"""Build a labelled diagnostic through the same validated LNI pipeline."""
from pathlib import Path
import argparse,subprocess,sys
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--name',required=True)
parser.add_argument('--profile',choices=['stages','idle','clock'],default='stages')
parser.add_argument('--clients',type=int,choices=range(1,7),default=1)
args=parser.parse_args()
subprocess.run([sys.executable,'tools/build.py','--name',args.name,'--clients',str(args.clients),
                '--test','--diagnostic',args.profile,'--ticks','3000' if args.profile=='clock' else '75000'],cwd=root,check=True)
print('DIAGNOSTIC MAP READY:',args.name+'.w3x')
