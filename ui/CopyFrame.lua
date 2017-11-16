local Main = ListenerAddon
Main.CopyFrame = {}
local Me = Main.CopyFrame

function Me.Show( text )
	ListenerCopyFrame.text:SetText( text )
	ListenerCopyFrame:Show()
end
