local OldFlare = Flare
local OldCharge = DepthCharge
local OldRedirect = MissileRedirect
--All of these have been hooked to add a check in OnCollisionCheck() to exclude hitboxes from the possible sets.
Flare = Class(OldFlare){
    OnCollisionCheck = function(self,other)
        if not other.HitBox and EntityCategoryContains(ParseEntityCategory(self.RedirectCat), other) and self.Army ~= other.Army and IsAlly(self.Army, other.Army) == false then
            other:SetNewTarget(self.Owner)
        end
        return false
    end,
}

DepthCharge = Class(OldCharge) {
    OnCollisionCheck = function(self,other)
        if self.ProjectilesToDeflect > 0 then
            if not other.HitBox and self.Army ~= other.Army and IsEnemy(self.Army, other.Army) then
                if other.Blueprint.CategoriesHash["TORPEDO"] then
                    self.ProjectilesToDeflect = self.ProjectilesToDeflect - 1
                    other:SetNewTarget(self.Owner)
                end
            end
        end
        return false
    end,
}

MissileRedirect = Class(OldRedirect) {
    WaitingState = State {
        OnCollisionCheck = function(self, other)
            if not other.HitBox and IsEnemy(self.Army, other.Army) and other ~= self.EnemyProj then
				if EntityCategoryContains(categories.MISSILE - (categories.STRATEGIC + categories.TACTICALNUKE), other) then
					LOG('Got here!')
					self.Enemy = other:GetLauncher()
					self.EnemyProj = other
					ChangeState(self, self.RedirectingState)
				end
            end
            return false
        end,
    },
}
