
ScriptAnimatedEffectControllerMixin = {};

function ScriptAnimatedEffectControllerMixin:Init(modelScene, effectID, source, target, onEffectFinish, onEffectResolution)
	self.modelScene = modelScene;
	self.effectID = effectID;
	self.source = source;
	self.target = target;
	self.onEffectFinish = onEffectFinish;
	self.onEffectResolution = onEffectResolution;

	self.activeBehaviors = {};
	self.effectCount = 0;

	self.loopingSoundEmitter = nil;
end

function ScriptAnimatedEffectControllerMixin:GetEffect()
	return ScriptedAnimationEffectsUtil.GetEffectByID(self.effectID);
end

function ScriptAnimatedEffectControllerMixin:StartEffect()
	self.effectCount = self.effectCount + 1;

	self.actor = self.modelScene:InternalAddEffect(self.effectID, self.source, self.target, self);

	local effect = self:GetEffect();
	if effect.startBehavior then
		self:BeginBehavior(effect.startBehavior);
	end

	if effect.loopingSoundKitID then
		local startingSound = nil;
		local loopingSound = effect.loopingSoundKitID;

		local endingSound = nil;
		local loopStartDelay = 0;
		local loopEndDelay = 0;
		local loopFadeTime = 0;
		self.loopingSoundEmitter = CreateLoopingSoundEffectEmitter(startingSound, loopingSound, endingSound, loopStartDelay, loopEndDelay, loopFadeTime);
		self.loopingSoundEmitter:StartLoopingSound();
	end
	
	if effect.startSoundKitID then
		PlaySound(effect.startSoundKitID, nil, SOUNDKIT_ALLOW_DUPLICATES);
	end
end

function ScriptAnimatedEffectControllerMixin:DeltaUpdate(elapsedTime)
	if self.actor then
		if self.actor:IsActive() then
			self.actor:DeltaUpdate(elapsedTime);
		else
			self:FinishEffect();
		end
	end

	local behaviorFinished = false;
	local currentTime = GetTime();
	local i = 1;
	while i <= #self.activeBehaviors do
		local activeBehaviors = self.activeBehaviors[i];
		if currentTime < activeBehaviors.finishTime then
			i = i + 1;
		else
			behaviorFinished = true;
			tUnorderedRemove(self.activeBehaviors, i);
		end
	end

	if behaviorFinished then
		self:CheckResolution();
	end
end

function ScriptAnimatedEffectControllerMixin:IsActive()
	return self.actor or #self.activeBehaviors > 0;
end

function ScriptAnimatedEffectControllerMixin:CancelLoopingSound()
	if self.loopingSoundEmitter then
		self.loopingSoundEmitter:CancelLoopingSound();
	end
end

function ScriptAnimatedEffectControllerMixin:FinishLoopingSound()
	if self.loopingSoundEmitter then
		self.loopingSoundEmitter:FinishLoopingSound();
	end
end

function ScriptAnimatedEffectControllerMixin:FinishEffect()
	local effect = self:GetEffect();
	if effect.finishBehavior then
		self:BeginBehavior(effect.finishBehavior);
	end

	if effect.finishSoundKitID then
		PlaySound(effect.finishSoundKitID, nil, SOUNDKIT_ALLOW_DUPLICATES);
	end

	self:RunEffectFinish();

	if self.actor then
		self.modelScene:ReleaseActor(self.actor);
		self.actor = nil;
	end

	self:FinishLoopingSound();

	if effect.finishEffectID then
		self.effectID = effect.finishEffectID;
		self:StartEffect();
		self:UpdateActorDynamicOffsets();
		self.actor:DeltaUpdate(0);
	end

	self:CheckResolution();
end

function ScriptAnimatedEffectControllerMixin:CheckResolution()
	if not self:IsActive() then
		self:RunEffectResolution();
	end
end

function ScriptAnimatedEffectControllerMixin:RunEffectResolution()
	if self.onEffectResolution then
		self.onEffectResolution(self.effectCount);
	end
end

function ScriptAnimatedEffectControllerMixin:RunEffectFinish()
	if self.onEffectFinish then
		if not self.onEffectFinish(self.effectCount) then
			self.onEffectFinish = nil;
		end
	end
end

function ScriptAnimatedEffectControllerMixin:SetDynamicOffsets(pixelX, pixelY, pixelZ)
	self.dynamicPixelX = pixelX;
	self.dynamicPixelY = pixelY;
	self.dynamicPixelZ = pixelZ;
	self:UpdateActorDynamicOffsets();
end

function ScriptAnimatedEffectControllerMixin:UpdateActorDynamicOffsets()
	self.actor:SetDynamicOffsets(self.dynamicPixelX, self.dynamicPixelY, self.dynamicPixelZ);
end

function ScriptAnimatedEffectControllerMixin:CancelEffect()
	self:InternalCancelEffect();
end

function ScriptAnimatedEffectControllerMixin:InternalCancelEffect(skipRemovingController)
	if not skipRemovingController then
		self.modelScene:RemoveEffectController(self);
	end

	self.modelScene:ReleaseActor(self.actor);

	for i, activeBehavior in ipairs(self.activeBehaviors) do
		activeBehavior.cancelFunction();
	end

	self.activeBehaviors = {};

	self:CancelLoopingSound();
	self:RunEffectFinish();
	self:RunEffectResolution();
end

function ScriptAnimatedEffectControllerMixin:BeginBehavior(behavior)
	local effect = self:GetEffect();
	local cancelFunction, duration = behavior(effect, self.source, self.target, self.modelScene:GetEffectSpeed());
	local finishTime = GetTime() + duration;
	table.insert(self.activeBehaviors, { cancelFunction = cancelFunction, finishTime = finishTime });
end
