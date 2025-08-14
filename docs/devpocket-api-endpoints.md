# DevPocket API Endpoints Documentation
# OpenAPI 3.0 Specification

openapi: 3.0.0
info:
  title: DevPocket API
  description: AI-Powered Mobile Terminal Backend API
  version: 1.0.0
  contact:
    name: DevPocket Support
    email: support@devpocket.app
    url: https://devpocket.app
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.devpocket.app
    description: Production server
  - url: https://staging-api.devpocket.app
    description: Staging server
  - url: http://localhost:8000
    description: Development server

tags:
  - name: Authentication
    description: User authentication and authorization
  - name: Terminal
    description: Terminal operations and command execution
  - name: AI
    description: AI-powered features and suggestions
  - name: Sync
    description: Cross-device synchronization
  - name: User
    description: User profile and settings
  - name: Subscription
    description: Subscription and billing

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      
  schemas:
    User:
      type: object
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
          format: email
        username:
          type: string
        subscription_tier:
          type: string
          enum: [free, pro, team, enterprise]
        created_at:
          type: string
          format: date-time
          
    Session:
      type: object
      properties:
        id:
          type: string
          format: uuid
        user_id:
          type: string
          format: uuid
        device_id:
          type: string
        device_type:
          type: string
          enum: [ios, android, web]
        created_at:
          type: string
          format: date-time
          
    Command:
      type: object
      properties:
        id:
          type: string
          format: uuid
        session_id:
          type: string
          format: uuid
        command:
          type: string
        output:
          type: string
        status:
          type: string
          enum: [pending, running, success, error]
        exit_code:
          type: integer
        created_at:
          type: string
          format: date-time
        executed_at:
          type: string
          format: date-time
          
    AIRequest:
      type: object
      required:
        - prompt
      properties:
        prompt:
          type: string
          description: Natural language prompt
        context:
          type: array
          items:
            type: object
            properties:
              role:
                type: string
                enum: [user, assistant, system]
              content:
                type: string
        model:
          type: string
          default: claude-3-haiku
          enum: [claude-3-haiku, gpt-4o-mini, gpt-4o]
          
    AIResponse:
      type: object
      properties:
        suggestion:
          type: string
        explanation:
          type: string
        confidence:
          type: number
          format: float
          minimum: 0
          maximum: 1
        tokens_used:
          type: integer
          
    Error:
      type: object
      properties:
        code:
          type: string
        message:
          type: string
        details:
          type: object

paths:
  # ============================================================================
  # AUTHENTICATION ENDPOINTS
  # ============================================================================
  
  /api/auth/register:
    post:
      tags:
        - Authentication
      summary: Register new user
      operationId: registerUser
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - email
                - username
                - password
              properties:
                email:
                  type: string
                  format: email
                username:
                  type: string
                  minLength: 3
                  maxLength: 30
                password:
                  type: string
                  minLength: 8
                device_id:
                  type: string
                device_type:
                  type: string
                  enum: [ios, android]
      responses:
        '201':
          description: User created successfully
          content:
            application/json:
              schema:
                type: object
                properties:
                  user_id:
                    type: string
                    format: uuid
                  token:
                    type: string
                  token_type:
                    type: string
                  expires_in:
                    type: integer
        '400':
          description: Invalid input or user already exists
          
  /api/auth/login:
    post:
      tags:
        - Authentication
      summary: Login user
      operationId: loginUser
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - username
                - password
              properties:
                username:
                  type: string
                  description: Username or email
                password:
                  type: string
                device_id:
                  type: string
                device_type:
                  type: string
                  enum: [ios, android]
      responses:
        '200':
          description: Login successful
          content:
            application/json:
              schema:
                type: object
                properties:
                  user_id:
                    type: string
                    format: uuid
                  token:
                    type: string
                  token_type:
                    type: string
                  expires_in:
                    type: integer
        '401':
          description: Invalid credentials
          
  /api/auth/refresh:
    post:
      tags:
        - Authentication
      summary: Refresh access token
      operationId: refreshToken
      security:
        - bearerAuth: []
      responses:
        '200':
          description: Token refreshed
          content:
            application/json:
              schema:
                type: object
                properties:
                  token:
                    type: string
                  expires_in:
                    type: integer
                    
  /api/auth/logout:
    post:
      tags:
        - Authentication
      summary: Logout user
      operationId: logoutUser
      security:
        - bearerAuth: []
      responses:
        '200':
          description: Logout successful
          
  # ============================================================================
  # TERMINAL ENDPOINTS
  # ============================================================================
  
  /api/ssh/connect:
    post:
      tags:
        - Terminal
      summary: Connect to SSH server
      operationId: connectSSH
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - host
                - username
              properties:
                host:
                  type: string
                port:
                  type: integer
                  default: 22
                username:
                  type: string
                password:
                  type: string
                private_key:
                  type: string
                  description: Base64 encoded private key
                passphrase:
                  type: string
      responses:
        '200':
          description: SSH connection established
          content:
            application/json:
              schema:
                type: object
                properties:
                  session_id:
                    type: string
                    format: uuid
                  status:
                    type: string
                    
  /api/ssh/profiles:
    get:
      tags:
        - Terminal
      summary: Get saved SSH profiles
      operationId: getSSHProfiles
      security:
        - bearerAuth: []
      responses:
        '200':
          description: List of SSH profiles
          content:
            application/json:
              schema:
                type: array
                items:
                  type: object
                  properties:
                    id:
                      type: string
                    name:
                      type: string
                    host:
                      type: string
                    port:
                      type: integer
                    username:
                      type: string
                    
    post:
      tags:
        - Terminal
      summary: Save SSH profile
      operationId: saveSSHProfile
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - name
                - host
                - username
              properties:
                name:
                  type: string
                host:
                  type: string
                port:
                  type: integer
                username:
                  type: string
                private_key_id:
                  type: string
      responses:
        '201':
          description: Profile saved
          
  /api/commands/execute:
    post:
      tags:
        - Terminal
      summary: Execute terminal command
      operationId: executeCommand
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - command
              properties:
                command:
                  type: string
                session_id:
                  type: string
                  format: uuid
                timeout:
                  type: integer
                  default: 30
      responses:
        '200':
          description: Command executed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Command'
                
  /api/commands/history:
    get:
      tags:
        - Terminal
      summary: Get command history
      operationId: getCommandHistory
      security:
        - bearerAuth: []
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
            default: 100
            maximum: 1000
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
        - name: session_id
          in: query
          schema:
            type: string
            format: uuid
        - name: status
          in: query
          schema:
            type: string
            enum: [pending, running, success, error]
        - name: search
          in: query
          schema:
            type: string
      responses:
        '200':
          description: Command history retrieved
          content:
            application/json:
              schema:
                type: object
                properties:
                  commands:
                    type: array
                    items:
                      $ref: '#/components/schemas/Command'
                  total:
                    type: integer
                  has_more:
                    type: boolean
                    
  /api/commands/{command_id}:
    get:
      tags:
        - Terminal
      summary: Get specific command
      operationId: getCommand
      security:
        - bearerAuth: []
      parameters:
        - name: command_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Command details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Command'
                
  /api/commands/{command_id}/rerun:
    post:
      tags:
        - Terminal
      summary: Rerun command
      operationId: rerunCommand
      security:
        - bearerAuth: []
      parameters:
        - name: command_id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Command rerun initiated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Command'
                
  # ============================================================================
  # AI ENDPOINTS
  # ============================================================================
  
  /api/ai/suggest:
    post:
      tags:
        - AI
      summary: Get AI command suggestion (BYOK)
      operationId: getAISuggestion
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - prompt
                - api_key
              properties:
                prompt:
                  type: string
                  description: Natural language prompt
                api_key:
                  type: string
                  description: User's OpenRouter API key
                context:
                  type: array
                  items:
                    type: object
                model:
                  type: string
                  default: claude-3-haiku
      responses:
        '200':
          description: AI suggestion generated
          content:
            application/json:
              schema:
                type: object
                properties:
                  suggestion:
                    type: string
                  cached:
                    type: boolean
        '401':
          description: Invalid API key
        '429':
          description: Rate limited by OpenRouter
          
  /api/ai/explain:
    post:
      tags:
        - AI
      summary: Explain command error (BYOK)
      operationId: explainError
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - command
                - error
                - api_key
              properties:
                command:
                  type: string
                error:
                  type: string
                api_key:
                  type: string
                  description: User's OpenRouter API key
      responses:
        '200':
          description: Error explanation generated
          content:
            application/json:
              schema:
                type: object
                properties:
                  explanation:
                    type: string
                  suggestions:
                    type: array
                    items:
                      type: string
                      
  /api/ai/validate-key:
    post:
      tags:
        - AI
      summary: Validate OpenRouter API key
      operationId: validateApiKey
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - api_key
              properties:
                api_key:
                  type: string
                  description: OpenRouter API key to validate
      responses:
        '200':
          description: Validation result
          content:
            application/json:
              schema:
                type: object
                properties:
                  valid:
                    type: boolean
                  models:
                    type: array
                    items:
                      type: string
                    description: Available models for this key
                    description: Available models for this key
                      
  /api/ai/complete:
    post:
      tags:
        - AI
      summary: Autocomplete command (BYOK)
      operationId: autocompleteCommand
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - partial_command
                - api_key
              properties:
                partial_command:
                  type: string
                api_key:
                  type: string
                  description: User's OpenRouter API key
                context:
                  type: array
                  items:
                    type: string
      responses:
        '200':
          description: Autocomplete suggestions
          content:
            application/json:
              schema:
                type: object
                properties:
                  completions:
                    type: array
                    items:
                      type: string
                    
  # ============================================================================
  # SYNC ENDPOINTS
  # ============================================================================
  
  /api/sync/commands:
    post:
      tags:
        - Sync
      summary: Sync commands across devices
      operationId: syncCommands
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                commands:
                  type: array
                  items:
                    $ref: '#/components/schemas/Command'
                last_sync:
                  type: string
                  format: date-time
      responses:
        '200':
          description: Commands synced
          content:
            application/json:
              schema:
                type: object
                properties:
                  synced:
                    type: integer
                  conflicts:
                    type: array
                    items:
                      type: object
                      
  /api/sync/settings:
    get:
      tags:
        - Sync
      summary: Get synced settings
      operationId: getSyncedSettings
      security:
        - bearerAuth: []
      responses:
        '200':
          description: Settings retrieved
          content:
            application/json:
              schema:
                type: object
                properties:
                  theme:
                    type: string
                  font_size:
                    type: integer
                  shortcuts:
                    type: object
                  ai_preferences:
                    type: object
                    
    put:
      tags:
        - Sync
      summary: Update synced settings
      operationId: updateSyncedSettings
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
      responses:
        '200':
          description: Settings updated
          
  # ============================================================================
  # USER ENDPOINTS
  # ============================================================================
  
  /api/user/profile:
    get:
      tags:
        - User
      summary: Get user profile
      operationId: getUserProfile
      security:
        - bearerAuth: []
      responses:
        '200':
          description: User profile
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
                
    put:
      tags:
        - User
      summary: Update user profile
      operationId: updateUserProfile
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                username:
                  type: string
                email:
                  type: string
                  format: email
      responses:
        '200':
          description: Profile updated
          
  /api/user/devices:
    get:
      tags:
        - User
      summary: Get user devices
      operationId: getUserDevices
      security:
        - bearerAuth: []
      responses:
        '200':
          description: List of devices
          content:
            application/json:
              schema:
                type: array
                items:
                  type: object
                  properties:
                    device_id:
                      type: string
                    device_type:
                      type: string
                    device_name:
                      type: string
                    last_active:
                      type: string
                      format: date-time
                      
  # ============================================================================
  # SUBSCRIPTION ENDPOINTS
  # ============================================================================
  
  /api/subscription/plans:
    get:
      tags:
        - Subscription
      summary: Get available plans
      operationId: getSubscriptionPlans
      responses:
        '200':
          description: List of plans
          content:
            application/json:
              schema:
                type: array
                items:
                  type: object
                  properties:
                    plan_id:
                      type: string
                    name:
                      type: string
                    price:
                      type: number
                    features:
                      type: array
                      items:
                        type: string
                        
  /api/subscription/current:
    get:
      tags:
        - Subscription
      summary: Get current subscription
      operationId: getCurrentSubscription
      security:
        - bearerAuth: []
      responses:
        '200':
          description: Current subscription details
          content:
            application/json:
              schema:
                type: object
                properties:
                  plan_id:
                    type: string
                  status:
                    type: string
                  current_period_end:
                    type: string
                    format: date-time
                  cancel_at_period_end:
                    type: boolean
                    
  # ============================================================================
  # WEBSOCKET ENDPOINT
  # ============================================================================
  
  /ws/terminal:
    get:
      tags:
        - Terminal
      summary: WebSocket terminal connection with SSH/PTY support
      operationId: websocketTerminal
      parameters:
        - name: token
          in: query
          required: true
          schema:
            type: string
      responses:
        '101':
          description: Switching Protocols
          headers:
            Upgrade:
              schema:
                type: string
                example: websocket
            Connection:
              schema:
                type: string
                example: Upgrade
                
      x-websocket-messages:
        client-to-server:
          - type: command
            description: Execute single command
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [command]
                data:
                  type: string
                  description: Command to execute
                  
          - type: connect_ssh
            description: Connect to SSH server
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [connect_ssh]
                config:
                  type: object
                  properties:
                    host:
                      type: string
                    port:
                      type: integer
                    username:
                      type: string
                    password:
                      type: string
                    key_path:
                      type: string
                      
          - type: create_pty
            description: Create local PTY session
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [create_pty]
                  
          - type: pty_input
            description: Send input to PTY
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [pty_input]
                data:
                  type: string
                  description: Input to send to PTY
                  
          - type: resize_pty
            description: Resize PTY window
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [resize_pty]
                cols:
                  type: integer
                rows:
                  type: integer
                  
          - type: ai_convert
            description: Convert natural language to command
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [ai_convert]
                prompt:
                  type: string
                api_key:
                  type: string
                  description: User's OpenRouter API key
                  
        server-to-client:
          - type: pty_output
            description: PTY output stream
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [pty_output]
                data:
                  type: string
                  
          - type: ssh_connected
            description: SSH connection established
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [ssh_connected]
                session_id:
                  type: string
                  
          - type: pty_created
            description: PTY session created
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [pty_created]
                session_id:
                  type: string
                  
          - type: ai_suggestion
            description: AI generated command
            payload:
              type: object
              properties:
                type:
                  type: string
                  enum: [ai_suggestion]
                command:
                  type: string