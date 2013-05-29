import sys, os
from glob import glob
from AutoDockTools.Docking import Docking
from AutoDockTools.cluster import Clusterer
from MolKit.pdbWriter import PdbWriter

# pdbqt to pdb
def write_pdb(pdbqt_parser, outfile):
  mol = pdbqt_parser[0]
  mol.buildBondsByDistance()
  mol.allAtoms.number = range(1, len(mol.allAtoms) + 1)
  
  writer = PdbWriter()
  writer.write(outfile, mol.allAtoms, records=['HETATM'], sort=1, bondOrigin=0)


def main():
  dlgs = glob('*.dlg')

  if len(dlgs) == 0:
    sys.exit(1)

  if os.path.exists('target') is False:
    os.mkdir('target')

  ligands = []
  receptors = []

  for filename in dlgs:
    dlg=filename[:-4]
    (lig, rec) = dlg.split('--____--')
    if not lig in ligands:
      ligands.append(lig)
    if not rec in receptors:
      receptors.append(rec)
  
  res = [[] for i in ligands]
  for i in range(len(res)):
    res[i] = ['' for j in receptors]

  for filename in dlgs:
    dlg=filename[:-4]
    (lig, rec) = dlg.split('--____--')

    d = Docking()
    d.readDlg(filename)

    lines = d.ligMol.parser.allLines
    for i in range(len(lines)):
      line = lines[i]
      if line.find("\n") == -1:
        d.ligMol.parser.allLines[i] = line + "\n"

    if not hasattr(d, 'clusterer'):
      d.clusterer = Clusterer(d.ch.conformations, sort="binding_energy")

    clist = [d.clusterer.data[int(i)] for i in d.clusterer.argsort]

    energy = clist[0].binding_energy

    res[ligands.index(lig)][receptors.index(rec)] = "%.2f" % energy

    d.ligMol.parser.allLines = d.ligMol.parser.write_with_new_coords(clist[0].getCoords())

    write_pdb(d.ligMol.parser.parse(), 'target/%s.pdb' % dlg)

  res_file = open('target/result.txt', 'w')
  print>>res_file, ",%s" % ",".join(receptors)
  for i in range(len(res)):
    print>>res_file, "%s,%s" % (ligands[i], ",".join(res[i]))
  res_file.close()

if __name__ == '__main__':
  main()
