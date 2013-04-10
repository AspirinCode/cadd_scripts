# -*- coding: utf-8 -*- #
import os, sys, getopt
from glob import glob
from MolKit import Read
from AutoDockTools.Docking import Docking
from AutoDockTools.cluster import Clusterer
from MolKit.pdbWriter import PdbWriter


outdir = 'target'
VERBOSE = None

def usage():
    print "从 autodock 日志文件 .dlg 获取能量最低 n 项（默认为10）存储为 pdb 文件"
    print "用法：write_ligands_by_energy.py[ -l <logfile>][ -n <num>]"
    print "例子：write_ligands_by_energy.py -l Fenoldopam_1_rec.dpf.dlg"
    print
    print "    可选参数："
    print "        -l, --logfile   指定 autodock 日志文件 .dlg"
    print "                        如 Fenoldopam_1_rec.dpf.dlg 或 docks/*.dlg"
    print "                        不指定时为当前目录下所有 .dlg 文件"
    print "        -n, --num       存储能量最低的 n 项，n > 0，不指定时为 10"
    print "        -v, --verbose   debug"
    print "        -h, --help      显示此帮助"

def error(errno, msg):
    err = {
        1: '未找到指定 dlg 文件，请正确指定文件',
        2: '',
        3: '-n, -num 必须为正整数'
    }
    if msg is None:
        msg = err[errno]
    print 'Errno(' + str(errno) + '): ' + msg
    sys.exit(errno)

# hack for getopt
def parse_argv(argv):
    dic = {'0': []}
    option = '0'
    for i in argv:
        if i[0] == '-':
            option = i
            dic[option] = []
        else:
            dic[option].append(i)

    lis = []
    for name in dic:
        value = dic[name]
        if name is not '0':
            lis.append(name)
        if len(value) == 1:
            lis.append(value[0])
        if len(value) > 1:
            lis.append(value)

    return lis

def parse_dlg(dlgfilename, num, result):
    global VERBOSE

    d = Docking()
    d.readDlg(dlgfilename)

    if num > 1:
        workdir = outdir + '/' + d.ligMol.name
        if os.path.exists(workdir) is False:
            os.mkdir(workdir)
    if num == 1:
        workdir = outdir


    if num > 1:
        log = {'name': d.ligMol.name, 'num': num, 'target': workdir}
        if VERBOSE:
            print log
        print>>result, log

    lines = d.ligMol.parser.allLines
    for i in range(len(lines)):
        line = lines[i] 
        if line.find("\n")==-1:
            d.ligMol.parser.allLines[i] = line + "\n"


    if not hasattr(d, 'Clusterer'):
        d.clusterer = Clusterer(d.ch.conformations, sort='energy')

    clist = []

    for i in d.clusterer.argsort:
        clist.append(d.clusterer.data[int(i)])

    for i in range(0, num):
        conf = clist[i]
        outfile = workdir + '/' + d.ligMol.name + '_' + str(i + 1) + '.pdb'
        energy = '%.2f' % round(conf.energy, 2)

        mylog = {'name': outfile, 'energy': energy}
        if VERBOSE:
            print mylog
        print>>result, mylog

        d.ligMol.parser.allLines = d.ligMol.parser.write_with_new_coords(conf.getCoords())

        write_pdb(d.ligMol.parser.parse(), outfile)

# pdbqt to pdb
def write_pdb(pdbqt_parser, outfile):
    mol = pdbqt_parser[0]
    mol.buildBondsByDistance()
    mol.allAtoms.number = range(1, len(mol.allAtoms) + 1)
    
    writer = PdbWriter()
    writer.write(outfile, mol.allAtoms, records=['HETATM'], sort=1, bondOrigin=0)

def main():
    global VERBOSE

    try:
        opt_list, args = getopt.getopt(parse_argv(sys.argv[1:]), 'l:n:vh', ['logfile=', 'num=', 'verbose', 'help'])
    except getopt.GetoptError, msg:
        print msg
        usage()
        error(2, msg)

    dlgs = glob('*.dlg')
    num = 10

    for o, a in opt_list:
        if o in ('-l', '--logfile'):
            if isinstance(a, str) and len(a) > 0:
                a = [a]
            dlgs = a
        if o in ('-n', '--num'):
            num = int(a)
            if num < 1:
                error(3, None)
        if o in ('-v', '--verbose'):
            VERBOSE = True
        if o in ('-h', '--help'):
            usage()
            sys.exit()

    if len(dlgs) == 0:
        error(1, None)
        usage()

    if os.path.exists(outdir) is False:
        os.mkdir(outdir)

    if VERBOSE:
        print {'files': dlgs, 'num': num}

    result = open(outdir + '/result.txt', 'w')
    print>>result, {'files': dlgs, 'num': num}

    for filename in dlgs:
        parse_dlg(filename, num, result)

    result.close()

if __name__ == '__main__':
    main()
