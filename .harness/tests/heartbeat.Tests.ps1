BeforeAll {
    . "$PSScriptRoot/../lib/heartbeat.ps1"
}

Describe 'Invoke-HeartbeatReduce' {
    Context 'system.init' {
        It 'resets all fields and sets last_action to init' {
            $state = @{ turns = 5; elapsed_s = 10; last_action = 'tool:bash' }
            $event = @{ type = 'system.init' }
            $result = Invoke-HeartbeatReduce -State $state -Event $event
            $result.turns       | Should -Be 0
            $result.elapsed_s   | Should -Be 0
            $result.last_action | Should -Be 'init'
        }
    }

    Context 'assistant.text' {
        It 'increments turns by one' {
            $state = @{ turns = 2; elapsed_s = 0; last_action = 'init' }
            $event = @{ type = 'assistant.text'; text = 'hello' }
            $result = Invoke-HeartbeatReduce -State $state -Event $event
            $result.turns | Should -Be 3
        }

        It 'sets last_action to thinking' {
            $state = @{ turns = 0; elapsed_s = 0; last_action = 'init' }
            $event = @{ type = 'assistant.text'; text = 'hello' }
            $result = Invoke-HeartbeatReduce -State $state -Event $event
            $result.last_action | Should -Be 'thinking'
        }
    }

    Context 'tool_use' {
        It 'sets last_action to tool:<name>' {
            $state = @{ turns = 1; elapsed_s = 0; last_action = 'thinking' }
            $event = @{ type = 'tool_use'; name = 'bash' }
            $result = Invoke-HeartbeatReduce -State $state -Event $event
            $result.last_action | Should -Be 'tool:bash'
        }

        It 'falls back to tool:tool when name is absent' {
            $state = @{ turns = 1; elapsed_s = 0; last_action = 'thinking' }
            $event = @{ type = 'tool_use' }
            $result = Invoke-HeartbeatReduce -State $state -Event $event
            $result.last_action | Should -Be 'tool:tool'
        }
    }

    Context 'result' {
        It 'updates elapsed_s from event' {
            $state = @{ turns = 3; elapsed_s = 0; last_action = 'thinking' }
            $event = @{ type = 'result'; elapsed_s = 42.5 }
            $result = Invoke-HeartbeatReduce -State $state -Event $event
            $result.elapsed_s | Should -Be 42.5
        }

        It 'sets last_action to done' {
            $state = @{ turns = 3; elapsed_s = 0; last_action = 'thinking' }
            $event = @{ type = 'result'; elapsed_s = 10 }
            $result = Invoke-HeartbeatReduce -State $state -Event $event
            $result.last_action | Should -Be 'done'
        }
    }

    Context 'unknown event' {
        It 'returns state unchanged' {
            $state = @{ turns = 2; elapsed_s = 5.0; last_action = 'thinking' }
            $event = @{ type = 'future.unrecognised'; data = 'x' }
            $result = Invoke-HeartbeatReduce -State $state -Event $event
            $result.turns       | Should -Be 2
            $result.elapsed_s   | Should -Be 5.0
            $result.last_action | Should -Be 'thinking'
        }
    }
}
