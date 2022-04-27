require "test_helper"

class SentMessageTest < ActiveSupport::TestCase
  include NotificationsHelper

  setup do
    @developer = developers(:prospect)
    @business = businesses(:subscriber)
    @conversation = conversations(:one)
    @user = @developer.user
  end

  test "creating a message is successful" do
    assert_difference "Message.count", 1 do
      result = create_sent_message!
      assert result.success?
      assert_equal Message.last, result.message
    end
  end

  test "invalid messages are not created" do
    assert_no_difference "Message.count" do
      result = create_sent_message!(body: nil)
      refute result.success?
      assert result.message.invalid?
    end
  end

  test "creating a message sends a notification to the recipient" do
    assert_difference "Notification.count", 1 do
      result = create_sent_message!

      notification = last_message_notification
      assert_equal notification.type, NewMessageNotification.name
      assert_equal notification.recipient, @business.user
      assert_equal notification.to_notification.message, result.message
      assert_equal notification.to_notification.conversation, conversations(:one)
    end
  end

  test "no one else can contribute to the conversation" do
    @user = users(:empty)
    assert create_sent_message!.unauthorized?
  end

  test "part-time plan subscribers can't message full-time seekers" do
    @user = users(:subscribed_business)
    pay_subscriptions(:full_time).update!(processor_plan: BusinessSubscription::PartTime.new.plan)
    @developer.role_type.update!(
      part_time_contract: false,
      full_time_contract: false,
      full_time_employment: true
    )

    assert create_sent_message!.unauthorized?
  end

  def create_sent_message!(options = {body: "Hello!"})
    SentMessage.new(options, user: @user, conversation: @conversation, sender: @developer).create
  end
end