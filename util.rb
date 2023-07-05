module Util
  def timestamp(time = Time.now)
    # 2020-05-23T18:17:56.715Z
    time.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
  end
end
