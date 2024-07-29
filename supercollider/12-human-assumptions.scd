~src = Buffer.read(s,FluidFilesPath("Tremblay-ASWINE-ScratchySynth-M.wav"));
~src.play;

// look at a diagram of pitch analysis
// blue is detected pitch
// orange is algorithm's confidence about pitch
(
fork{
	~pitchbuf = Buffer(s);
	FluidBufPitch.processBlocking(s,~src,features:~pitchbuf);
	s.sync;
	defer{
		FluidWaveform(~src,featuresBuffer:~pitchbuf,stackFeatures:true);
	}
}
)

// straight average
// (median might be better than this mean)
(
~statsbuf = Buffer(s);
FluidBufStats.processBlocking(s,~pitchbuf,numChans:1,stats:~statsbuf,select:[\mean],action:{
	~statsbuf.loadToFloatArray(action:{
		arg fa;
		FluidBufStats.stats.do{
			arg stat, i;
			"%:\t%".format(stat,fa[i]).postln;
		};

		~src.play;
		{
			SinOsc.ar(fa[0]) * -30.dbamp;
		}.play(outbus:1);
	});
});
)

// weighted average using pitch confidence for weights
// use confidence curve as our weights
(
~weightsbuf = Buffer(s);
FluidBufCompose.processBlocking(s,~pitchbuf,startChan:1,numChans:1,destination:~weightsbuf);  // copy confidence curve
FluidBufStats.processBlocking(s,~pitchbuf,numChans:1,stats:~statsbuf,weights:~weightsbuf,action:{
	~statsbuf.loadToFloatArray(action:{
		arg fa;
		FluidBufStats.stats.do{
			arg stat, i;
			"%:\t%".format(stat,fa[i]).postln;
		};

		~src.play;
		{
			SinOsc.ar(fa[0]) * -30.dbamp;
		}.play(outbus:1);
	});
});
)

// weighted average using loudness for weights
(
~loudbuf = Buffer(s);
FluidBufLoudness.processBlocking(s,~src,features:~loudbuf,select:[\loudness]);
~loudbuf_scaled = Buffer(s);
FluidBufScale.processBlocking(s,~loudbuf,destination:~loudbuf_scaled,inputLow:-40,inputHigh:0,clipping:3);
FluidBufStats.processBlocking(s,~pitchbuf,numChans:1,stats:~statsbuf,weights:~loudbuf_scaled,action:{
	~statsbuf.loadToFloatArray(action:{
		arg fa;
		FluidBufStats.stats.do{
			arg stat, i;
			"%:\t%".format(stat,fa[i]).postln;
		};

		~src.play;
		{
			SinOsc.ar(fa[0]) * -30.dbamp;
		}.play(outbus:1);
	});
});
)

// decompose
(
~resynth = Buffer(s);
~bases = Buffer(s);
FluidBufNMF.processBlocking(s,~src,resynth:~resynth,resynthMode:1,bases:~bases,components:2,action:{
	defer{ ~bases.plot };
});
)

~resynth.play;

// rewrites ~src buffer to fill it with just the one component
FluidBufCompose.processBlocking(s,~resynth,startChan:1,numChans:1,destination:~src);

// eyeball it rather than doing fancy analyses...
(
{
	var sig = PlayBuf.ar(1,~src,BufRateScale.ir(~src));
	FluidPitch.kr(sig).poll;
	sig;
}.play;
)

// chroma

(
{
	var src = PlayBuf.ar(1,~src,BufRateScale.ir(~src));
	var chroma = FluidChroma.kr(src);
	var max, pc, sig;
	chroma.poll;
	# max, pc = ArrayMax.kr(chroma);
	sig = LFTri.ar((57 + pc).midicps) * -30.dbamp;
	[src,sig];
}.play;
)