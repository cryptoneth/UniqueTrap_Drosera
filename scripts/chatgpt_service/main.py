import os
import time
from web3 import Web3
from openai import OpenAI
from dotenv import load_dotenv
from eth_account import Account

# Load environment variables from .env file
load_dotenv()

# --- Configuration ---
RPC_URL = os.getenv("RPC_URL")
PRIVATE_KEY = os.getenv("PRIVATE_KEY")
CHATGPT_INFO_STORE_ADDRESS = os.getenv("CHATGPT_INFO_STORE_ADDRESS")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# --- Web3 Setup ---
w3 = Web3(Web3.HTTPProvider(RPC_URL))
if not w3.is_connected():
    print("Failed to connect to Web3 provider!")
    exit()

account = Account.from_key(PRIVATE_KEY)
w3.eth.default_account = account.address

print(f"Connected to blockchain. Account: {account.address}")

# --- Contract ABI (from ChatGPTInfoStore.sol) ---
CHATGPT_INFO_STORE_ABI = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "encodedChatGPTInfo",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "owner",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "renounceOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "transferOwnership",
    "inputs": [
      {
        "name": "newOwner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "updateInfo",
    "inputs": [
      {
        "name": "_newInfo",
        "type": "string",
        "internalType": "string"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "ChatGPTInfoUpdated",
    "inputs": [
      {
        "name": "newInfo",
        "type": "string",
        "indexed": False,
        "internalType": "string"
      }
    ],
    "anonymous": False
  },
  {
    "type": "event",
    "name": "OwnershipTransferred",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": True,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": True,
        "internalType": "address"
      }
    ],
    "anonymous": False
  },
  {
    "type": "error",
    "name": "OwnableInvalidOwner",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "OwnableUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ]
  }
]

chatgpt_info_store_contract = w3.eth.contract(
    address=CHATGPT_INFO_STORE_ADDRESS,
    abi=CHATGPT_INFO_STORE_ABI
)

# --- OpenAI Setup ---
openai_client = OpenAI(api_key=OPENAI_API_KEY)

# --- Main Logic ---
def get_sentiment_sentence(text_to_analyze: str) -> str:
    """
    Asks the AI for a sentiment analysis and returns the full sentence response.
    """
    prompt = f"Analyze the sentiment of the following text and respond with a full sentence, including the word POSITIVE, NEUTRAL, or NEGATIVE. Text: '{text_to_analyze}'"
    try:
        response = openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful assistant who analyzes sentiment."},
                {"role": "user", "content": prompt}
            ]
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"Error getting ChatGPT response: {e}")
        return ""

def update_onchain_info(info_sentence: str):
    """
    Pushes the provided sentence to the on-chain info store.
    """
    print(f"Attempting to update on-chain info with: '{info_sentence}'")
    try:
        transaction = chatgpt_info_store_contract.functions.updateInfo(info_sentence).build_transaction({
            'from': account.address,
            'nonce': w3.eth.get_transaction_count(account.address),
            'gas': 200000,
            'gasPrice': w3.eth.gas_price
        })
        signed_txn = w3.eth.account.sign_transaction(transaction, private_key=PRIVATE_KEY)
        tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)
        print(f"Transaction sent. Tx Hash: {tx_hash.hex()}")
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        if receipt.status == 1:
            print("On-chain info updated successfully!")
        else:
            print("Transaction failed!")
    except Exception as e:
        print(f"Error updating on-chain info: {e}")

if __name__ == "__main__":
    # A list of sample texts to test our sentiment trap
    sample_texts = [
        "This project is incredible, the technology is revolutionary and the team is top-notch!",
        "I'm not sure how I feel about the latest update, it has some good and bad points.",
        "This is a complete disaster, the platform is buggy and I'm selling everything. This is very NEGATIVE."
    ]

    # Loop through the sample texts and update the on-chain data
    for text in sample_texts:
        print(f"\n--- Analyzing new text: '{text[:50]}...' ---")
        sentiment_sentence = get_sentiment_sentence(text)

        if sentiment_sentence:
            update_onchain_info(sentiment_sentence)
        else:
            print("Could not get a response from ChatGPT.")
        
        print("Waiting for 30 seconds before next analysis...")
        time.sleep(30) # Wait for 30 seconds

    print("\nScript finished.")