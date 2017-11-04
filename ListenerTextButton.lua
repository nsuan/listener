
local Main = ListenerAddon

-------------------------------------------------------------------------------
local methods = {
-------------------------------------------------------------------------------
	SetText = function( self, text )
		self.text:SetText( text )
	end;
	SetFont = function( self, font )
		self.text:SetFontObject( font )
	end;
}

-------------------------------------------------------------------------------
function Main.TextButton_Init( self )
	for k,v in pairs( methods ) do
		self.k = self.v
	end
	self.text:SetJustifyH( "CENTER" )
	self:SetFont( ListenerBarFont )
end

-------------------------------------------------------------------------------
