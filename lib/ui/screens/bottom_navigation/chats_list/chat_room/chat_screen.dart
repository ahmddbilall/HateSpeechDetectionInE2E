import 'dart:developer';

import 'package:chat_app/core/constants/colors.dart';
import 'package:chat_app/core/constants/styles.dart';
import 'package:chat_app/core/extension/widget_extension.dart';
import 'package:chat_app/core/models/user_model.dart';
import 'package:chat_app/core/services/chat_service.dart';
import 'package:chat_app/ui/screens/auth/login/login_screen.dart';
import 'package:chat_app/ui/screens/bottom_navigation/chats_list/chat_room/chat_viewmodel.dart';
import 'package:chat_app/ui/screens/bottom_navigation/chats_list/chat_room/chat_widgets.dart';
import 'package:chat_app/ui/screens/other/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.receiver});
  final UserModel receiver;

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    log("👤 Current user is null? ${currentUser}");
    log("👤 Sender: ${currentUser?.uid}"); // Make sure this is not null
log("📨 Receiver: ${receiver.uid}"); // Must be valid too

    return ChangeNotifierProvider(
      create: (context) => ChatViewmodel(ChatService(), currentUser!, receiver),
      child: Consumer<ChatViewmodel>(builder: (context, model, _) {
        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 1.sw * 0.05, vertical: 10.h),
                  child: Column(
                    children: [
                      35.verticalSpace,
                      _buildHeader(context, name: receiver.name!),
                      15.verticalSpace,
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(0),
                          itemCount: model.messages.length,
                          separatorBuilder: (context, index) =>
                              10.verticalSpace,
                          itemBuilder: (context, index) {
                            final message = model.messages[index];
                            return ChatBubble(
                              isCurrentUser:
                                  message.senderId == currentUser!.uid,
                              message: message,
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
              // ⬇️ BottomField with manual IconButton for Send
              Container(
                color: grey.withOpacity(0.2),
                padding: EdgeInsets.symmetric(
                    horizontal: 1.sw * 0.05, vertical: 25.h),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20.r,
                      backgroundColor: white,
                      child: const Icon(Icons.add),
                    ),
                    10.horizontalSpace,
                    Expanded(
                      child: TextField(
                        controller: model.controller,
                        decoration: InputDecoration(
                          hintText: "Write message...",
                          fillColor: white,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12.w),
                        ),
                      ),
                    ),
                    Consumer<ChatViewmodel>(
  builder: (context, model, _) {
    log("🧠 ChatViewmodel instance: $model");
    log("👤 Current user uid: ${model.controller.text}");

    return IconButton(
      icon: const Icon(Icons.send, color: Colors.blue),
      onPressed: () async {
        log("💬 Send icon pressed from ChatScreen");
        try {
          await model.saveMessage();
          log("📤 Message send attempted");
        } catch (e) {
          log("❌ Error sending: $e");
          context.showSnackbar(e.toString());
        }
      },
    );
  },
),


                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Row _buildHeader(BuildContext context, {String name = ""}) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                color: grey.withOpacity(0.15)),
            child: const Icon(Icons.arrow_back_ios),
          ),
        ),
        15.horizontalSpace,
        Text(
          name,
          style: h.copyWith(fontSize: 20.sp),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              color: grey.withOpacity(0.15)),
          child: const Icon(Icons.more_vert),
        ),
      ],
    );
  }
}

