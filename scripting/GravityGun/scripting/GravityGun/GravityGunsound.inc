/*
 *sound functions at here
 */
 
#if defined _GravityGunsound_included
#endinput
#endif
#define _GravityGunsound_included

enum soundtype{

	SOUNDTYPE_GRAVITYGUN_DROP,
	SOUNDTYPE_GRAVITYGUN_PICKUP,
	SOUNDTYPE_GRAVITYGUN_PUNT,
	SOUNDTYPE_GRAVITYGUN_MOTION

};

enum soundspecification{
	
	SOUND_FIRST = 0,
	SOUND_GRAVITYGUN_DROP = 0,
	SOUND_GRAVITYGUN_PICKUP,
	SOUND_GRAVITYGUN_HOLD,
	SOUND_GRAVITYGUN_PUNT1,
	SOUND_GRAVITYGUN_PUNT2,
	SOUND_GRAVITYGUN_PUNT3,
	SOUND_GRAVITYGUN_PUNT4,
	SOUND_GRAVITYGUN_MOTION1,
	SOUND_GRAVITYGUN_MOTION2,
	SOUND_LAST

};

new const String:sounddata[SOUND_LAST][128] = {
	
	"weapons/physcannon/physcannon_drop.wav",
	"weapons/physcannon/physcannon_pickup.wav",
	"weapons/physcannon/hold_loop.wav",
	"weapons/physcannon/superphys_launch1.wav",
	"weapons/physcannon/superphys_launch2.wav",
	"weapons/physcannon/superphys_launch3.wav",
	"weapons/physcannon/superphys_launch4.wav",
	"weapons/airboat/airboat_gun_lastshot1.wav",
	"weapons/airboat/airboat_gun_lastshot2.wav"
	
};

stock prepatchsounds(){
	
	//소리 프리패치, 쓰이는 모든 소리를 프리패치한다
	for(new soundspecification:i = SOUND_FIRST; i < SOUND_LAST; i++){
		
		PrecacheSound(sounddata[i], true);
		
	}
	
}

stock playsound(entity = SOUND_FROM_WORLD, soundtype:soundtypetoplay, Float:soundposition[3]){
	
	if(!soundenabled()){
	
		return;
	
	}
	
	if(soundtypetoplay == SOUNDTYPE_GRAVITYGUN_DROP){
		
		EmitSoundToAll(sounddata[SOUND_GRAVITYGUN_DROP], entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, soundposition, NULL_VECTOR, true, 0.0);
		
	}else if(soundtypetoplay == SOUNDTYPE_GRAVITYGUN_PICKUP){
		
		EmitSoundToAll(sounddata[SOUND_GRAVITYGUN_PICKUP], entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, soundposition, NULL_VECTOR, true, 0.0);
		
	}else if(soundtypetoplay == SOUNDTYPE_GRAVITYGUN_PUNT){
		
		EmitSoundToAll(sounddata[GetRandomInt(SOUND_GRAVITYGUN_PUNT1, SOUND_GRAVITYGUN_PUNT4)], entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, soundposition, NULL_VECTOR, true, 0.0);
		
	}else if(soundtypetoplay == SOUNDTYPE_GRAVITYGUN_MOTION){
		
		EmitSoundToAll(sounddata[GetRandomInt(SOUND_GRAVITYGUN_MOTION1, SOUND_GRAVITYGUN_MOTION2)], entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, soundposition, NULL_VECTOR, true, 0.0);
		
	}
	
}

//소리를 재생하는 엔티티를 지정하는 함수, 지정된 엔티티의 위치가 바뀜에 따라 소리도 자동으로 따라가며, 소리파일에 반복플래그가 있는 경우 수동으로 멈추기 전까지 계속 반복된다
stock playentitysound(entity, soundspecification:sound, Float:soundposition[3]){
	
	if(!soundenabled()){
	
		return;
	
	}
	
	EmitSoundToAll(sounddata[sound], entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5, SNDPITCH_NORMAL, -1, soundposition, NULL_VECTOR, true, 2.0);
	
}

//playentitysound 함수로 재생한 소리는 이 함수를 써서 멈춰야 한다
stock stopentitysound(entity, soundspecification:sound){
	
	StopSound(entity, SNDCHAN_AUTO, sounddata[sound]);
	
}

stock playsoundfromclient(client, soundtype:soundtypetoplay){

	decl Float:eyeposition[3];
	GetClientEyePosition(client, eyeposition);
	playsound(client, soundtypetoplay, eyeposition);

}

stock playentitysoundfromclient(client, soundspecification:sound){

	decl Float:eyeposition[3];
	GetClientEyePosition(client, eyeposition);
	playentitysound(client, sound, eyeposition);

}