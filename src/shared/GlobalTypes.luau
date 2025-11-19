export type BagData<T> = {
  instance: T
}


export type PathInfo = {
  points: { Attachment },
  positions: { Vector3 },
  segments: { number },
  cumulative: { number },
  total_length: number,
}

export type ConveyorConfig = {
  spawn_rate: number
}
export type ConveyorData<T> = {
  instance: T,
  spawned_bags: {BagData<Attachment>},
  last_spawned_bag: number,

  is_busy: boolean,

  config: ConveyorConfig,
  path: PathInfo
}

return {}