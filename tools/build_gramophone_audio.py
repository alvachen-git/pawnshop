"""Build gramophone demonstrations from Victor 18615, recorded 1919-08-12.
Source/rights: assets/gramophone_desk/audio/SOURCE.md. numpy + soundfile required.
A normal machine retains historical surface noise. Faults are additional effects.
"""
from pathlib import Path
import sys, os, json, hashlib
ROOT=Path(__file__).resolve().parents[1]
if os.environ.get('GRAMOPHONE_AUDIO_DEPS'):
 sys.path.insert(0,os.environ['GRAMOPHONE_AUDIO_DEPS'])
import numpy as np
import soundfile as sf
OUT=ROOT/'assets/gramophone_desk/audio'
source=OUT/'source/victor-18615-waiting-1919.mp3'
x,sr=sf.read(source)
if x.ndim==2:x=x.mean(axis=1)
# Use a continuous musical passage rather than tiling a modern piano fragment.
x=x[int(12*sr):int(36*sr)]
# Downsample after a bandlimit to keep six mono files reasonably small.
f=np.fft.rfftfreq(len(x),1/sr)
x=np.fft.irfft(np.fft.rfft(x)/(1+(f/3600)**8),n=len(x))
if sr==44100:x=x[::2];sr=22050
f=np.fft.rfftfreq(len(x),1/sr)
# Acoustic horn emphasis: retain the original early recording's grain,
# remove sub-bass and modern bright treble, gently emphasize the midrange.
response=(1-np.exp(-(f/230)**2))/(1+(f/2900)**6)
response*=1+.25*np.exp(-((f-1250)/550)**2)
base=np.fft.irfft(np.fft.rfft(x)*response,n=len(x))
base*=.58/np.max(np.abs(base))
# Smooth repeated record boundary; playback engine loops PCM sample-accurately.
fade=int(.10*sr)
ramp=np.linspace(0,1,fade)
base[:fade]=base[:fade]*ramp+base[-fade:]*(1-ramp)
base=base[:-fade]
f=np.fft.rfftfreq(len(base),1/sr)
rng=np.random.default_rng(44)
wear=rng.normal(0,.009,len(base))
for at in np.arange(.35,len(base)/sr,.769):
 j=int(at*sr);n=min(int(.013*sr),len(base)-j)
 wear[j:j+n]+=rng.normal(0,.24,n)*np.exp(-np.arange(n)/(sr*.003))
report={"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"sample_start_seconds":12,"outputs":{}}
for condition in ['clear','rasping','muffled']:
 z=base.copy()
 if condition=='rasping':
  # Loose diaphragm: musical peaks buzz; distortion persists on both records.
  z=.48*np.tanh(base*8)+.30*base
  z*=np.sqrt(np.mean(base*base))/np.sqrt(np.mean(z*z))
 if condition=='muffled':
  z=np.fft.irfft(np.fft.rfft(base)/(1+(f/950)**6),n=len(base))*.72
 for worn in [False,True]:
  a=z+(wear if worn else 0)
  name=condition+('_worn' if worn else '')+'.wav'
  assert np.max(np.abs(a))<.98
  sf.write(OUT/name,a,sr,subtype='PCM_16')
  report['outputs'][name]={"seconds":len(a)/sr,"peak":float(np.max(np.abs(a))),"rms":float(np.sqrt(np.mean(a*a))),"sha256":hashlib.sha256((OUT/name).read_bytes()).hexdigest()}
print(json.dumps(report,indent=2))
(OUT/'BUILD_REPORT.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
