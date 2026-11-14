# 提取 CFPilot-dataplane zip 中的 worker 文件到当前目录（保留原始文件名）
import zipfile, glob, os, sys

os.chdir('upstream')
zips = [f for f in glob.glob('*.zip') if os.path.getsize(f) > 10000]
if not zips:
    print('::error::CFPilot-dataplane.zip 下载异常或为空')
    sys.exit(1)

z = zipfile.ZipFile(zips[0])
names = z.namelist()
target = '_worker.js' if '_worker.js' in names else names[0]
z.extract(target, '.')
print('提取完成:', target, os.path.getsize(target), '字节')
