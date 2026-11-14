# 提取上游 CFAPEX zip 中的 _worker.js 到 upstream/ 根目录
import zipfile, glob, os, sys

os.chdir('upstream')
zips = [f for f in glob.glob('*.zip') if os.path.getsize(f) > 10000]
if not zips:
    print('::error::上游 zip 下载异常或为空')
    sys.exit(1)

zf = zipfile.ZipFile(zips[0])
names = [n for n in zf.namelist() if n.endswith('_worker.js')]
target = names[0] if names else zf.namelist()[0]
zf.extract(target, '.')
print('提取完成:', target, os.path.getsize(target), '字节')
