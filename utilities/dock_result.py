# -*- coding: utf-8 -*- #
'''
' @section {DockView} UCSF Dock 6.x 结果分析
'
' @option {workdir}      ./       所有保存、读取文件操作的文件路径都相对于该路径
' @option {active}        ####    药物分子
' @option {inactive}     *.mol2   除药物分子外的分子，支持通配符*和?，多个文件用英文逗号分割
' @option {order}        gs       按 order 排序结果，可选 gs、vdw，分别表示 Grid Score、vdw
' @option {hit}          1%, 5%   保存排序前 top 的分子，并做相关计算，值可为百分数，或具体的数量，多个值用英文逗号分割
'''
from mol2 import *
from util import *
import re, os, time

def parseDockComment(comment):
  '''从注释获得 Dock 结果参数'''
  records = {}
  for line in comment:
    rec = re.compile(r'\:\s+').split(line.lstrip('#').strip())
    records[rec[0].lower()] = rec[1]
  return records

def handleModelList(models, config):
  '''处理 Dock 结果列表'''
  valid_models = []
  for mol in models:
    # 原子重叠的分子
    if mol.is_atom_dup:
      path = '%s/%s.mol2' % (config['allpath']['DUP'], mol.hash)
      mol.save(path)
      print '发现一分子存在原子坐标重叠，从列表中移除，并保存到' + path
      continue
    # 没有 Dock 结果记录的分子
    if not mol.headcomments:
      path = '%s/%s.mol2' % (config['allpath']['NO_RECORD'], mol.hash)
      mol.save(path)
      print '发现一分子找不到 Dock 结果，从列表中移除，并保存到' + path
      continue

    # 处理 Dock 结果参数
    mol.dock_records = parseDockComment(mol.headcomments)

    valid_models.append(mol)

  return valid_models

def main(config):
  score_name = {'gs': 'grid score', 'vdw': 'vdw'}[config['order']]
  split_str = '-' * 50

  outdir = makedir(makedir(config['workdir'] + '/target') + '/' + time.strftime('%Y_%m_%d_%H_%M_%S'))
  allpath = {
    'TOP': makedir(outdir + '/hits'),
    'DUP': makedir(outdir + '/atom_dups'),
    'NO_RECORDS': makedir(outdir + '/no_records'),
    'LOG': outdir + '/result.txt'
  }
  config['allpath'] = allpath

  # 加载药物和数据库
  print split_str
  print '加载药物和数据库'
  drugs = openMolecules(config['active'])
  models = openMolecules(config['inactive'])
  # 记录原始计数
  count_raw = {
    'drugs': len(drugs),
    'database': len(models),
    'total': len(drugs) + len(models)
  }

  # 去除无法进行计算的分子
  drugs = handleModelList(drugs, config)
  models = handleModelList(models, config)
  # 记录剩下的分子计数
  count_valid = {
    'drugs': len(drugs),
    'database': len(models),
    'total': len(drugs) + len(models)
  }
  print split_str
  print '原始计数：'
  print '  active: %i' % count_raw['drugs']
  print 'inactive: %i' % count_raw['database']
  print '   total: %i' % count_raw['total'] 
  print split_str
  print '有效计数：'
  print '  active: %i' % count_valid['drugs']
  print 'inactive: %i' % count_valid['database']
  print '   total: %i' % count_valid['total'] 

  # 索引药物列表
  drug_list = [drug.hash for drug in drugs]

  # 合并药物和数据库，进行下步计算
  models.extend(drugs)

  # 按 order 键索引所有分子
  dock_result = {}
  for mol in models:
    orderkey = mol.dock_records[score_name]
    if dock_result.has_key(orderkey):
      dock_result[orderkey].append(mol)
    else:
      dock_result[orderkey] = [mol]

  # 排序
  scores = map(float, dock_result.keys())
  scores.sort()

  # Hit List
  hit_list = map(lambda x: int(round(division(x[:-1], 100) * count_valid['total'])) if x[-1:] == '%' else int(x), config['hit'] )
  hit_list.sort()
  hit_max = hit_list[len(hit_list) - 1]

  # 保存前 top 位并记录
  top_counter = 1
  hit_max_list = []
  f = open(allpath['LOG'], 'w')
  print>>f, '\t'.join(['no', score_name.replace(' ', '_'), 'file', 'active'])
  num_len = str(len(str(hit_max)) + 1)
  for score in scores:
    for mol in dock_result['%6f' % score]:
      path = '%s/%s_%s.mol2' % (allpath['TOP'], ('%.' + num_len + 'i') % top_counter, mol.hash)
      mol.save(path)
      # (计数, 评分, 路径, 是否活性)
      res = (top_counter, score, os.path.basename(path), 'Y' if mol.hash in drug_list else 'N')
      print>>f, '%i\t%6f\t%s\t%s' % res
      hit_max_list.append(res)
      top_counter += 1
    if top_counter > hit_max:
      break
  f.close()
  print split_str
  print '按 %s 排序的结果前 %i 位记录在： %s' % ( score_name, hit_max, allpath['LOG'])

  # 计算相关数据
  if config['active']:
    for hit_num in hit_list:
      hit_rate = division(hit_num, count_valid['total'])
      active_hit = [x for x in hit_max_list[:hit_num] if x[3] == 'Y']
      active_hit_num = len(active_hit)
      ef = division(division(active_hit_num, count_valid['drugs']), hit_rate)

      print split_str
      print ' total hit: %i (%i%%)' % (hit_num, int(round(hit_rate * 100)))
      print 'active hit: %i' % active_hit_num
      print '        EF: %f' % ef

  print split_str
    

if __name__ == '__main__':
  defaultConfig = {
    'workdir': './',
    'active': '####',
    'inactive': '*.mol2',
    'order': 'gs',
    'hit': '1%, 5%',
  }
  configType = {
    'active': 'glob',
    'inactive': 'glob',
    'hit': list,
    'order': ['gs', 'vdw']
  }
  config = readConfig('config.ini', defaultConfig, configType)
  main(config)
