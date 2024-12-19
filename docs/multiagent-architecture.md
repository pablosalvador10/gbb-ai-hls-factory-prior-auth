# Multi-Agent Architecture Documentation

## Overview

The multi-agent architecture implements a collaborative system of specialized AI agents that work together to process and evaluate prior authorization requests. The system uses Semantic Kernel as its foundation and implements a group chat pattern where agents take turns performing their specialized tasks.

## System Architecture

### 1. Core Components

#### Semantic Kernel Integration
- Built on Microsoft's Semantic Kernel framework
- Utilizes Azure OpenAI services for agent intelligence
- Implements plugin system for extensible functionality

#### Agent Framework
- Custom Agent class implementation
- Supports skill/plugin integration
- Configurable execution settings
- Built-in telemetry and logging

### 2. Agent Types

#### Formulator Agent
- **Purpose**: Creates optimized search queries from clinical metadata
- **Responsibilities**:
  - Analyzes clinical metadata
  - Identifies key details and requirements
  - Formulates precise search queries
- **Configuration**:
  ```python
  agent_formulator = Agent(
      service_id="formulator",
      name=FORMULATOR_NAME,
      instructions=FORMULATOR_INSTRUCTIONS,
      execution_settings=PromptExecutionSettings(
          temperature=0.0,
          max_tokens=2000,
          top_p=0.8
      )
  )
  ```

#### Retriever Agent
- **Purpose**: Searches and retrieves relevant policy documents
- **Responsibilities**: 
  - Classifies query type (semantic/keyword/hybrid)
  - Executes appropriate search strategy
  - Returns relevant document results
- **Configuration**:
  ```python
  agent_retriever = Agent(
      service_id="retriever",
      name=RETRIEVER_NAME,
      instructions=RETRIEVER_INSTRUCTIONS,
      execution_settings=execution_settings,
      skills=["retrieval"],
      tracing_enabled=True
  )
  ```

#### Evaluator Agent
- **Purpose**: Evaluates search results against original query
- **Responsibilities**:
  - Analyzes result relevance
  - Eliminates duplicates
  - Provides reasoning for selections
- **Configuration**:
  ```python
  agent_evaluator = Agent(
      service_id="evaluator",
      name=EVALUATOR_NAME,
      instructions=EVALUATOR_INSTRUCTIONS,
      execution_settings=execution_settings,
      tracing_enabled=True
  )
  ```

### 3. Orchestration Components

#### AgentGroupChat
```python
chat = AgentGroupChat(
    agents=[agent_formulator, agent_retriever, agent_evaluator],
    termination_strategy=ApprovalTerminationStrategy(
        maximum_iterations=10,
        agents=[agent_evaluator]
    ),
    selection_strategy=KernelFunctionSelectionStrategy(...)
)
```

- **Turn Management**:
  - Fixed workflow pattern:
    1. Formulator → creates query
    2. Retriever → searches documents
    3. Evaluator → assesses results
  - Managed by KernelFunctionSelectionStrategy
  - Configurable termination conditions

#### Selection Strategy
- Uses prompt-based function for agent selection
- Ensures sequential workflow execution
- Prevents agent repetition
- Customizable selection logic

#### Termination Strategy
- Implements ApprovalTerminationStrategy
- Monitors for completion conditions
- Ends workflow when evaluator approves results
- Configurable maximum iterations (default: 10)

### 4. Plugin System

#### Retrieval Plugin
```python
kernel.add_plugin(
    parent_directory="plugins_store",
    plugin_name="retrieval"
)
```

**Core Functions**:
- `classify_search_query`: Determines optimal search strategy
- `semantic_search`: Performs semantic similarity search
- `keyword_search`: Performs keyword-based search
- `hybrid_search`: Combines semantic and keyword search

### 5. Communication Flow

1. **Input Processing**:
   ```python
   await chat.add_chat_message(ChatMessageContent(
       role=AuthorRole.USER,
       content="Clinical metadata..."
   ))
   ```

2. **Agent Interaction**:
   ```python
   async for content in chat.invoke():
       # Process agent responses
       agent_name = content.name
       agent_role = content.role
       agent_output = content.content
   ```

3. **Output Format**:
   ```json
   {
     "policies": ["path/to/policy1.pdf"],
     "reasoning": ["Reasoning for selection..."],
     "retry": false
   }
   ```

### 6. Telemetry and Logging

#### AIFoundry Integration
```python
ai_foundry_manager = AIFoundryManager()
ai_foundry_manager.initialize_telemetry()
```

#### Logging Configuration
```python
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("Kernel")
```

#### OpenTelemetry Setup
```python
trace_provider = TracerProvider(
    resource=Resource({"service.name": "AgentGroupChatService"})
)
trace_provider.add_span_processor(
    BatchSpanProcessor(ConsoleSpanExporter())
)
```

## Best Practices

1. **Error Handling**:
   - Implement try-catch blocks for agent operations
   - Handle API failures gracefully
   - Provide meaningful error messages

2. **Monitoring**:
   - Track agent performance metrics
   - Monitor API usage and quotas
   - Log important events and errors

3. **Security**:
   - Secure API keys and credentials
   - Validate input data
   - Implement rate limiting

4. **Testing**:
   - Unit test individual agents
   - Integration test agent interactions
   - End-to-end workflow testing

## Limitations and Considerations

1. **Performance Dependencies**:
   - Azure OpenAI service availability
   - API response times
   - Model quality and limitations

2. **Scalability Considerations**:
   - Rate limiting requirements
   - Resource consumption
   - Concurrent request handling

3. **Maintenance Requirements**:
   - Regular prompt engineering updates
   - Model version management
   - Plugin system updates

This architecture provides a robust and extensible framework for processing prior authorization requests through collaborative AI agents, with comprehensive logging, monitoring, and error handling capabilities.
