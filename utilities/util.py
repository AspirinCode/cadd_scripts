# -*- coding: utf-8 -*- #
from pprint import pprint
from ConfigParser import ConfigParser
from glob import glob
import os, re, sys

def division(a, b):
  return float(a) / float(b)

def dump(obj, depth=False, private=False):
  if depth:
    tmp = {}
    for attr in dir(obj):
      if private is False and attr[:2] == '__':
        continue
      tmp[attr] = getattr(obj, attr)
    pprint(tmp, indent=2)

    pprint({'Raw': obj, 'Type': type(obj)}, indent=2)
  else:
    pprint(obj, indent=2)

def makedir(path):
  if os.path.exists(path) is False:
    os.mkdir(path)
  return os.path.realpath(path)

def readConfig(f, defaults, configType={}):
  split_str = '-' * 50
  print '%s\n读取参数：\n%s' % (split_str, split_str)
  config = ConfigParser(defaults)
  config.read(f)
  section = config.sections()[0]

  if config.has_option(section, 'workdir'):
    workdir = os.path.realpath(config.get(section, 'workdir'))
  else:
    workdir = os.path.realpath('.')
  
  if not os.path.exists(workdir):
    raise ValueError, '指定路径 %s 不存在' % workdir

  config.set(section, 'workdir', workdir)

  print '- workdir: ' + workdir
  options = {}
  for option in config.items(section):
    (key, value) = (option[0].lower(), option[1])
    if key == 'workdir':
      options[key] = workdir
      continue
    if value == '####':
      options[key] = ''
      print '- %s:' % key
      continue

    if key in configType:
      t = configType[key]
      # glob 类型
      if t == 'glob':
        options[key] = []
        for path in value.split(','):
          path = path.strip() if os.path.isabs(path) else '%s/%s' % (workdir, path.strip())
          options[key].extend(glob(path))
        if options[key] == []:
          raise ValueError, '%s: 没有匹配的文件 `%s\' in `%s/\'' % (key, value, workdir)
      # 列表，所有项返回字符串类型
      if t == list:
        options[key] = [x.strip() for x in value.split(',')]
        if options[key] == []:
          raise ValueError, '%s: 没有正确填写 `%s\' 值' % (key, key)
      # 转整数
      if t == int:
        options[key] = int(value)
      # 转浮点数
      if t == float:
        options[key] = float(value)
      # Yes、No 转布尔量
      if t == bool:
        options[key] = True if value.lower() == 'yes' else False
      # 判断是否在列表内
      if type(t) == list:
        if value in t:
          options[key] = value
        else:
          raise ValueError, '%s 的值无效，必须为下列中的一项：%s' % (key, '、'.join(t))
    else:
      # 普通字符串
      options[key] = value
      if options[key] == '':
        raise ValueError, '%s 值为空' % key

    if type(options[key]) == list:
      print '- %s:' % key
      for item in options[key]:
        print '\t- %s' % (item if not configType[key] == 'glob' else os.path.relpath(item, workdir))
    else:
      print '- %s: ' % key + str(options[key])

  print split_str
  while True:
    prompt = raw_input('请确认配置是否正确(Y or N): ').strip()
    if prompt.upper() == 'Y':
      break
    if prompt.upper() == 'N':
      sys.exit('用户取消了此次操作')
  return options

def writeFileByLines(path, lines):
  f = open(path, 'w')
  f.writelines(lines)
  f.close()
