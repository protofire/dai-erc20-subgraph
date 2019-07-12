import { BigDecimal, BigInt, Address } from "@graphprotocol/graph-ts";
import {
  Transfer as TransferEvent,
  Contract as Dai
} from "../generated/Contract/Contract";
import { Transfer, Account } from "../generated/schema";

function getDaiInstance(address: Address): Dai {
  return Dai.bind(address);
}

function castToDecimal(value: BigInt, decimalsCount: BigInt): BigDecimal {
  return value.divDecimal(decimalsCount.toBigDecimal());
}

export function handleTransfer(event: TransferEvent): void {
  let dai = getDaiInstance(event.address);

  let transfer = new Transfer(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  );
  transfer.src = event.params.src;
  transfer.account = event.params.src.toHex();
  transfer.dst = event.params.dst;
  transfer.value = castToDecimal(event.params.wad, dai.decimals());
  transfer.save();


  let account = new Account(transfer.account);
  account.save();
}
