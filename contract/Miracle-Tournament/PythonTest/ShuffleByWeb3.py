from web3 import Web3
from web3.middleware import geth_poa_middleware
from eth_account import Account

# RPC 설정 -----------------------------------------------------------------
# Mainnet
# rpcAddr = "https://polygon-rpc.com"
# rpcChainId = "137"

# Testnet
rpcAddr = "https://polygon-testnet.public.blastapi.io"
rpcChainId = "80001"

# WEB3 정의 -----------------------------------------------------------------
web3 = Web3(Web3.HTTPProvider(rpcAddr))
web3.middleware_onion.inject(geth_poa_middleware, layer=0)

# WEB3 PK를 이용한 주소 식별 ---------------------------------------------------
myKey = "325962bcc363ca2cb8ccff90f2217df8aa2c76f70469e10950cfdaa19166d67c"
account = Account.from_key(myKey)
myAddr = account.address

# 컨트렉트 정의 주소/ABI -------------------------------------------------------
contractAddress = "0x3eDd7B41FF22c8744Ef582c6ae163D89B485B128"
contractABI = open('TournamentR2ABI.json', 'r', encoding='UTF-8').read()
contract = web3.eth.contract(address=contractAddress, abi=contractABI)

# 가스 제한 수동설정 -----------------------------------------------------------
gasLimit = 500000

# 플레이어 셔플 함수 호출
def call_players_shuffle(tournament_id):
    nonce = web3.eth.get_transaction_count(myAddr)
    transaction = contract.functions.playersShuffle(tournament_id).buildTransaction({
        'from': myAddr,
        'gas': gasLimit,
        'nonce': nonce
    })
    signed_txn = web3.eth.account.sign_transaction(transaction, private_key=myKey)
    tx_hash = web3.eth.send_raw_transaction(signed_txn.rawTransaction)
    return tx_hash

# playersShuffle 함수 호출 예시
tournamentId = 1
transaction_hash = call_players_shuffle(tournamentId)
print("Transaction Hash:", transaction_hash)