import wave,math,random,struct
from pathlib import Path
random.seed(24)
out=Path(__file__).resolve().parents[1] / 'assets' / 'audio';out.mkdir(exist_ok=True)
for name,duration in [('slice',.16),('combo',.38),('bomb',.6),('miss',.25)]:
 samples=[]; low=0
 for i in range(int(22050*duration)):
  t=i/22050;u=t/duration;n=random.uniform(-1,1);low=.88*low+.12*n
  if name=='slice':v=(n*.24+math.sin(2*math.pi*(1000*t-1800*t*t))*.12)*math.sin(math.pi*u)**2
  elif name=='combo':v=sum(math.sin(2*math.pi*f*t) for f in [659.25,830.61,987.77])*.09*(1-u)**2*min(1,t*100)
  elif name=='bomb':v=(low*.8+math.sin(2*math.pi*(80*t-40*t*t))*.25)*(1-u)**2
  else:v=math.sin(2*math.pi*(270*t-250*t*t))*.16*math.sin(math.pi*u)**2
  samples.append(struct.pack('<h',int(max(-1,min(1,v))*32767)))
 with wave.open(str(out/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(22050);w.writeframes(b''.join(samples))
