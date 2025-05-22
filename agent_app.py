import streamlit as st
import time
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

credential=DefaultAzureCredential()

# Set page configuration
st.set_page_config(
    page_title="CCUS Agent",
    page_icon="🌍",
    layout="wide"
)

# Add custom CSS
st.markdown("""
<style>
    .main {
        padding: 2rem;
    }
    .chat-message {
        padding: 1rem;
        border-radius: 0.5rem;
        margin-bottom: 1rem;
        display: flex;
        flex-direction: column;
    }
    .chat-message.user {
        background-color: #e6f7ff;
        border-left: 5px solid #1890ff;
    }
    .chat-message.assistant {
        background-color: #f6ffed;
        border-left: 5px solid #52c41a;
    }
    .chat-message .message-content {
        margin-top: 0.5rem;
    }
    .stButton button {
        width: 100%;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if "messages" not in st.session_state:
    st.session_state.messages = []
if "thread_id" not in st.session_state:
    st.session_state.thread_id = None
if "question" not in st.session_state:
    st.session_state.question = ""

# Title and description
st.title("CCUS Agent")
st.markdown("Ask questions about Carbon Capture, Utilization, and Storage (CCUS) technologies and feasibility.")

# Sidebar with information
with st.sidebar:
    st.header("About")
    st.info("This application uses Azure AI Projects to provide information about CCUS technologies and feasibility assessments.")
    
    # Connection settings
    st.subheader("Connection Settings")
    conn_str = st.text_input("Connection String", value="eastus2.api.azureml.ms;b83c3b1a-dcaa-4c04-ba2c-4890372a6a45;auxzee-rg-dev;ccus-agent", type="password")
    agent_id = st.text_input("Agent ID", value="asst_YprTpPtZyG0fVEFazLIc5UDC")
    
    # Create new thread button
    if st.button("Start New Conversation"):
        try:
            with st.spinner("Creating new thread..."):
                # Initialize the client
                project_client = AIProjectClient.from_connection_string(
                    credential=credential,
                    conn_str=conn_str
                )
                
                # Create a new thread
                thread = project_client.agents.create_thread()
                st.session_state.thread_id = thread.id
                st.session_state.messages = []
                st.success(f"New thread created: {thread.id}")
        except Exception as e:
            st.error(f"Error creating thread: {str(e)}")

# Display chat messages
for message in st.session_state.messages:
    with st.container():
        if message["role"] == "user":
            st.markdown(f"""
            <div class="chat-message user">
                <div><strong>You</strong></div>
                <div class="message-content">{message["content"]}</div>
            </div>
            """, unsafe_allow_html=True)
        else:
            st.markdown(f"""
            <div class="chat-message assistant">
                <div><strong>Assistant</strong></div>
                <div class="message-content">{message["content"]}</div>
            </div>
            """, unsafe_allow_html=True)

# Function to process the query
def process_query():
    if not st.session_state.question:
        st.warning("Please enter a question.")
        return
    
    if st.session_state.thread_id is None:
        st.warning("Please start a new conversation first.")
        return
    
    # Add user message to chat
    st.session_state.messages.append({"role": "user", "content": st.session_state.question})
    
    # Display "thinking" message
    thinking_placeholder = st.empty()
    thinking_placeholder.info("Thinking...")
    
    try:
        # Initialize the client
        project_client = AIProjectClient.from_connection_string(
            credential=credential,
            conn_str=conn_str
        )
        
        # Get the agent
        agent = project_client.agents.get_agent(agent_id)
        
        # Get the thread
        thread = project_client.agents.get_thread(st.session_state.thread_id)
        
        # Create message
        project_client.agents.create_message(
            thread_id=thread.id,
            role="user",
            content=st.session_state.question
        )
        
        # Reset question
        current_question = st.session_state.question
        st.session_state.question = ""
        
        # Create and process run
        run = project_client.agents.create_and_process_run(
            thread_id=thread.id,
            agent_id=agent.id
        )
        
        # Get messages
        messages = project_client.agents.list_messages(thread_id=thread.id)
        
        print("===============")
        print(messages)
        print("===============")
        
        # Get the latest assistant message
        assistant_messages = []
        
        # Check if messages has a 'data' attribute that contains the message list
        if hasattr(messages, 'data'):
            for msg in messages.data:
                if msg.role == "assistant":
                    assistant_messages.append(msg)
        
        if assistant_messages:
            latest_message = assistant_messages[-1]
            # Extract the text from the content array
            if latest_message.content and len(latest_message.content) > 0:
                # Get the first content item that is of type 'text'
                text_contents = [item for item in latest_message.content if getattr(item, 'type', None) == 'text']
                if text_contents:
                    response_content = text_contents[0].text.value
                    
                    # Add assistant message to chat
                    st.session_state.messages.append({"role": "assistant", "content": response_content})
                    
                    # Remove thinking message
                    thinking_placeholder.empty()
                    
                    # Rerun to update UI
                    st.rerun()
                else:
                    thinking_placeholder.error("No text content found in the assistant message.")
            else:
                thinking_placeholder.error("No content found in the assistant message.")
        else:
            thinking_placeholder.error("No response received from the assistant.")
            
    except Exception as e:
        thinking_placeholder.error(f"Error: {str(e)}")

# Use a form for the input
with st.form(key="query_form"):
    user_question = st.text_area("Your question:", height=100, key="question_input")
    submit_button = st.form_submit_button("Send")
    
    if submit_button:
        st.session_state.question = user_question
        process_query()

# Initial instructions if no thread exists
if st.session_state.thread_id is None:
    st.info("👈 Start by clicking 'Start New Conversation' in the sidebar.")