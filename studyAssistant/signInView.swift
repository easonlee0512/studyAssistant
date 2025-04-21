//
//  ContentView.swift
//  test
//
//  Created by esley W on 2025/4/21.
//

import SwiftUI

struct SignInView: View {
    var body: some View {
        ZStack {
            // Background color
            Color(hex: "F3D4B7")
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Add getstart text to top-left
                
            
                
                // GET STARTED Text
                Text("GET STARTED")
                    .font(.custom("Roboto-Black", size: 64))
                    .tracking(3.84) // 6% of 64px
                    .lineSpacing(0)
                    .foregroundColor(Color(hex: "E09772"))
                    
                    .padding(.bottom, 50)
                Spacer()
                // Sign in with Apple button
                Button(action: {
                    // Handle Apple sign in
                }) {
                    HStack {
                        Spacer()
                        Text("Sign in with Apple")
                            .font(.custom("Roboto-Medium", size: 20))
                            .tracking(1.2) // 6% of 20px
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "FEECD8"))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 1, y: 1)
                    )
                    .frame(width: 280) // Fixed width for buttons
                }
                
                // Sign in with Google button
                Button(action: {
                    // Handle Google sign in
                }) {
                    HStack {
                        Spacer()
                        Text("Sign in with Google")
                            .font(.custom("Roboto-Medium", size: 20))
                            .tracking(1.2) // 6% of 20px
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "FEECD8"))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 1, y: 1)
                    )
                    .frame(width: 280) // Fixed width for buttons
                }
                
                Spacer()
                
                // Semi-transparent rectangle at bottom
                
            }
            .padding()
        }
    }
}


#Preview {
    SignInView()
}
