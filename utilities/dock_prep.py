from chimera import openModels, Molecule
from AddH import simpleAddHydrogens, hbondAddHydrogens
from AddCharge import initiateAddCharges 
from WriteMol2 import *
from glob import glob
import sys, os, md5
from util import *

def render(status):
  print status

def hashdata(mol2data):
  return md5.new('\n'.join(mol2data)).hexdigest()

def handleFailures(raw):
  failures = makedir('failures')
  try:
    writeMol2([raw], '%s/%s.mol2' % (failures, hashdata(raw.mol2data)))
  except:
    os.mkdir('%s/%s_error' % (failures, hashdata(raw.mol2data)))
  print '# Fail preparing ' + hashdata(raw.mol2data)
  print '----------------------'

def addh(molecule):
  protSchemes = {'hisScheme': {}, 'gluScheme': {}, 'aspScheme': {}, 'lysScheme': {}, 'cysScheme': {}}
  try:
    hbondAddHydrogens(molecule, inIsolation=True, **protSchemes)
    return molecule
  except KeyboardInterrupt:
    print 'Stop by user'
    sys.exit()
  except:
    return None

def addcharge(molecule):
  AMBER99SB = "AMBER ff99SB"
  AMBER99bsc0 = "AMBER ff99bsc0"
  AMBER02pol_r1 = "AMBER ff02pol.r1"
  AMBER03ua = "AMBER ff03ua"
  AMBER03_r1 = "AMBER ff03.r1"
  AMBER12SB = "AMBER ff12SB"
  try:
    initiateAddCharges(models=molecule, method='am1-bcc', nogui=True, chargeModel=AMBER12SB)
    return molecule
  except KeyboardInterrupt:
    print 'Stop by user'
    sys.exit()
  except:
    return None

def main():
  molecules = chimera.openModels
  if len(molecules.list()):
    workdir = makedir('prepared')

    for molecule in molecules.list():
      name = hashdata(molecule.mol2data)

      if (os.path.exists('%s/%s.mol2' % (workdir, name)) or
        os.path.exists('failures/%s.mol2' % (name)) or 
        os.path.exists('failures/' + name)):
        print '# ' + name + ' is already prepared.'
        print '----------------------'
        continue

      # Add Hydrogens
      print '# Start adding hydrogens to ' + name
      hAdded = addh([molecule])
      if hAdded is None:
        handleFailures(molecule)
        continue

      # Add Charges
      print '# Start adding charges to ' + name
      chargeAdded = addcharge(hAdded)
      if chargeAdded is None:
        handleFailures(molecule)
        continue

      print '# Start writing molecule to ' + '%s/%s.mol2' % (workdir, name)
      writeMol2(chargeAdded, '%s/%s.mol2' % (workdir, name))
      print '----------------------'

    print '# Open prepared molecules and saving them to one file.'
    prepared = glob(workdir + '/*.mol2')
    if len(prepared):
      prepared_molecules = []
      for mol in prepared:
        prepared_molecules.append(chimera.openModels.open(mol)[0])

      writeMol2(prepared_molecules, 'done.mol2')

main()
