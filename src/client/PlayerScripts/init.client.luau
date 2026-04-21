--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local MutableTextComponent = require(ReplicatedStorage.shared.network.chat.MutableTextComponent)
local DialogueController = require(StarterPlayer.StarterPlayerScripts.client.modules.ui.dialogue.DialogueController)

task.wait(1)

DialogueController.typeOutDialogue(MutableTextComponent.literal("Alice"), "Nein", false)