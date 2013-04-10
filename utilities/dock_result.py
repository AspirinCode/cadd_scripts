# -*- coding: utf-8 -*- #
'''
' @section {DockView} UCSF Dock 6.x 结果分析
'
' @option {workdir}      ./      所有保存、读取文件操作的文件路径都相对于该路径
' @option {mol2file}     *.mol2  所有要分析的 mol2 文件，支持通配符*和?，多个文件用英文逗号分割
' @option {order}        gs      按 order 排序结果，可选 gs、vdw，分别表示 Grid Score、vdw
' @option {top}          100     获取排名前 top 位的分子
' @option {savename}     molname 保存分子时使用的文件名，可选 md5、molname，分别表示 唯一对应码、分子名+唯一对应码
'''
from mol2 import *
from util import *
import re, os, time

def main(config):
  score_hash = {'gs': 'grid score', 'vdw': 'vdw'}
  result_files = config['mol2file']

  workdir = config['workdir']
  outdir = makedir(makedir(workdir + '/target') + '/' + time.strftime('%Y_%m_%d_%H_%M_%S'))
  top_outdir = makedir('%s/top%i' % (outdir, config['top']))
  dup_outdir = makedir(outdir + '/atom_dups')
  no_record_outdir = makedir(outdir + '/no_records')
  result_path = outdir + '/result.txt'

  models = openMolecules(result_files)
  print '分子总数: %i' % len(models)

  fails = {'dup': [], 'no_dock': []}
  dock_result = {}
  for mol in models:
    if mol.is_atom_dup:
      fails['dup'].append(mol)
      mol.save(dup_outdir, config['savename'])
    else:
      if mol.headcomments:
        mol.dock_records = {}
        for line in mol.headcomments:
          record = re.compile(r'\:\s+').split(line.lstrip('#').strip())
          mol.dock_records[record[0].lower()] = record[1]

        orderkey = mol.dock_records[score_hash[config['order']]]
        if dock_result.has_key(orderkey):
          dock_result[orderkey].append(mol)
        else:
          dock_result[orderkey] = [mol]
      else:
        fails['no_dock'].append(mol)
        mol.save(no_record_outdir, config['savename'])

  scores = map(lambda x: float(x), dock_result)
  scores.sort()

  print '原子重叠的分子数: %i' % len(fails['dup'])
  print '没有对接结果的分子数: %i' % len(fails['no_dock'])

  save_count = 0
  f = open(result_path, 'w')
  print>>f, '%s,mol2file' % config['order']
  for score in scores:
    for mol in dock_result['%6f' % score]:
      path = mol.save(top_outdir, config['savename'])
      print>>f, '%6f,%s'%(score, os.path.basename(path))
      save_count += 1
    if save_count > 99:
      break
  f.close()
  print '按 %s 排序前 %i 的分子以保存到 %s' % (score_hash[config['order']], config['top'], top_outdir)

if __name__ == '__main__':
  defaultConfig = {
    'workdir': './',
    'mol2file': '*.mol2',
    'order': 'gs',
    'top': '100',
    'savename': 'molname'
  }
  configType = {
    'mol2file': 'glob',
    'top': int,
    'order': ['gs', 'vdw'],
    'savename': ['md5', 'molname']
  }
  config = readConfig('config.ini', defaultConfig, configType)
  main(config)
