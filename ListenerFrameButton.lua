
local Main = ListenerAddon

function Main.FrameButton_SetOn( self, on )
	self.on = on
	self:MyRefresh()
end

function Main.FrameButton_Refresh( self )
	self.bg:SetColorTexture( self.bgcolor[1], self.bgcolor[2], self.bgcolor[3], 
			                 self.on and 0.8 or 0.2 )
end

function Main.FrameButton_SetColor( self, r, g, b )
	self.bgcolor = {r,g,b}
	self:MyRefresh()
end
