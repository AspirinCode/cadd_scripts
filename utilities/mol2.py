# suppose that all the models won't end with comment lines
# and was spilted by '@<TRIPOS>MOLECULE'
import re, md5, os
def openMolecules(path):
  if type(path) is str:
    path = [path]

  # extract all files
  mol2datas = []
  for p in path:
    f = open(p)
    mol2datas.extend(f.readlines())
    f.close()

  # handle mol2datas
  mols = []
  current = -1
  ts = [] # temp store
  for line in mol2datas:
    line = line.strip()
    if line == '':
      continue

    ts.append(line + '\n')

    if line[0] == '#':
      continue

    if line == '@<TRIPOS>MOLECULE':
      mols.append(ts)
      current = len(mols) - 1
    else:
      mols[current].extend(ts)

    ts = []

  mol2_ins = []
  for mol in mols:
    mol2_ins.append(Molecule(mol))
  return mol2_ins

class Molecule:
  def __init__(self, mol2data):
    records = {}
    headcomments = []

    current_record = ''
    for line in mol2data:
      if line[0] == '#' and records == {}:
        headcomments.append(line)
        continue

      if line[:9].upper() == '@<TRIPOS>':
        current_record = line[9:].rstrip().upper()
        records[current_record] = []
      else:
        records[current_record].append(line)

    info = records['MOLECULE']
    self.name = info[0].rstrip()
    self.type = info[2].rstrip()
    self.charge_type = info[3].rstrip()
    self.data = mol2data
    self.records = records
    self.headcomments = headcomments
    self.is_atom_dup = None

    atoms = []
    coord_tz = []
    for atom in records['ATOM']:
      atom = Atom(atom)
      atoms.append(atom)
      if atom.coord in coord_tz:
        self.is_atom_dup = True
      else:
        coord_tz.append(atom.coord)

    self.atoms = atoms
    self.atom_num = len(atoms)

  def save(self, path, method):
    hashv = md5.new(''.join(self.data)).hexdigest()
    if method == 'molname':
      path = '%s/%s_%s.mol2' % (path, self.name, hashv)
    if method == 'md5':
      path = '%s/%s.mol2' % (path, hashv)

    f = open(path, 'w')
    f.writelines(self.data)
    f.close()
    return path

class Atom:
  def __init__(self, atom_record):
    parms = re.compile(r'\s+').split(atom_record.rstrip())
    self.id = parms[0]
    self.name = parms[1]
    self.coord = parms[2:5]
    self.type = parms[5]
    self.subst_id = parms[6] if parms[6:7] else None
    self.subst_name = parms[7] if parms[7:8] else None
    self.charge = parms[8] if parms[8:9] else None
    self.status_bit = parms[9] if parms[9:10] else None

