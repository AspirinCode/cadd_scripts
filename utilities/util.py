# -*- coding: utf-8 -*- #
from __future__ import print_function
from pprint import pprint
from ConfigParser import ConfigParser
from glob import glob
import os, re, sys

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
  print('读取参数：')
  config = ConfigParser(defaults)
  config.read(f)
  section = config.sections()[0]

  if config.has_option(section, 'workdir'):
    workdir = os.path.realpath(config.get(section, 'workdir'))
  else:
    workdir = os.path.realpath('.')

  config.set(section, 'workdir', workdir)
  
  if not os.path.exists(workdir):
      raise ValueError, '指定路径 %s 不存在' % workdir

  options = {}
  for option in config.items(section):
    (key, value) = (option[0].lower(), option[1])
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

    print('- %s : ' % key, end='')
    print(options[key])

  print('')
  while True:
    prompt = raw_input('请确认配置是否正确(Y or N): ').strip()
    if prompt.upper() == 'Y':
      break
    if prompt.upper() == 'N':
      sys.exit('用户取消了此次操作')

  return options
